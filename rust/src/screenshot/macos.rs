use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use crate::frb_generated::StreamSink;
use core_graphics::event::CGEvent;
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};
use screencapturekit::prelude::*;

use screencapturekit::stream::configuration::SCCaptureDynamicRange;

use crate::api::screen_shot_api::CaptureResult;

struct CaptureHandler {
    stream_sink: Arc<StreamSink<CaptureResult>>,
    captured: Arc<AtomicBool>,
    is_hdr: bool,
}

impl SCStreamOutputTrait for CaptureHandler {
    fn did_output_sample_buffer(&self, sample: CMSampleBuffer, _type: SCStreamOutputType) {
        // Only capture one frame
        if self.captured.swap(true, Ordering::SeqCst) {
            return;
        }

        // Get the image buffer from the sample
        if let Some(image_buffer) = sample.image_buffer() {
            // Get IOSurface for dimensions and pixel data
            if let Some(surface) = image_buffer.io_surface() {
                let width = surface.width() as u32;
                let height = surface.height() as u32;

                // Lock for CPU read access using IOSurfaceLockOptions
                use screencapturekit::cm::IOSurfaceLockOptions;
                if let Ok(lock_guard) = surface.lock(IOSurfaceLockOptions::READ_ONLY) {
                    // Get raw pixel data - IOSurfaceLockGuard implements Deref<Target=[u8]>
                    let bytes_per_row = lock_guard.bytes_per_row();

                    let slice: &[u8] = &*lock_guard;

                    // We must remove padding/stride manually
                    let bytes_per_pixel = 8; // RGhA is 64-bit
                    let valid_row_len = (width as usize) * bytes_per_pixel;
                    let mut raw_data = Vec::with_capacity(valid_row_len * height as usize);

                    for i in 0..height as usize {
                        let start = i * bytes_per_row;
                        let end = start + valid_row_len;
                        if end <= slice.len() {
                            raw_data.extend_from_slice(&slice[start..end]);
                        } else {
                            break;
                        }
                    }

                    // lock_guard drops here automatically unlocking the surface
                    drop(lock_guard);

                    if !raw_data.is_empty() {
                        let capture_result = CaptureResult {
                            // Mark mode as HDR or SDR for colorist to handle correctly
                            mode: if self.is_hdr {
                                "hdr_macos".to_string()
                            } else {
                                "sdr_macos".to_string()
                            },
                            raw_data,
                            frame_width: width,
                            frame_height: height,
                        };

                        let _ = self.stream_sink.add(capture_result);
                    }
                }
            }
        }
    }
}

pub fn take_full_screen_internal(stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    // Get available displays
    let content = SCShareableContent::get()
        .map_err(|e| anyhow::anyhow!("Failed to get shareable content: {:?}", e))?;

    let displays = content.displays();
    if displays.is_empty() {
        anyhow::bail!("No displays found");
    }

    // Get cursor position to determine which display to capture
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| anyhow::anyhow!("Failed to create CGEventSource"))?;
    let event = CGEvent::new(source).map_err(|_| anyhow::anyhow!("Failed to create CGEvent"))?;
    let cursor = event.location();

    // Find the display that contains the cursor
    let display = displays
        .iter()
        .find(|d| {
            let frame = d.frame();
            // Check if cursor is within display frame
            cursor.x >= frame.x
                && cursor.x < frame.x + frame.width
                && cursor.y >= frame.y
                && cursor.y < frame.y + frame.height
        })
        .unwrap_or(&displays[0]);

    // Configure capture filter
    let filter = SCContentFilter::create()
        .with_display(display)
        .with_excluding_windows(&[])
        .build();

    // Get display dimensions
    let width = display.width();
    let height = display.height();

    // Configure stream with HDR support
    // PixelFormat::RGhA is 64-bit RGBA IEEE half-precision float (compatible with Windows Rgba16F)
    // SCCaptureDynamicRange::HDRCanonicalDisplay provides portable HDR tone mapping
    let config = SCStreamConfiguration::new()
        .with_width(width)
        .with_height(height)
        .with_pixel_format(PixelFormat::RGhA) // HDR: 16-bit half-float per channel
        .with_capture_dynamic_range(SCCaptureDynamicRange::HDRLocalDisplay);

    // Setup capture handler
    let stream_sink_arc = Arc::new(stream_sink);
    let captured = Arc::new(AtomicBool::new(false));

    let handler = CaptureHandler {
        stream_sink: stream_sink_arc,
        captured: captured.clone(),
        is_hdr: true,
    };

    // Create and start stream
    let mut stream = SCStream::new(&filter, &config);
    stream.add_output_handler(handler, SCStreamOutputType::Screen);

    stream
        .start_capture()
        .map_err(|e| anyhow::anyhow!("Failed to start capture: {:?}", e))?;

    // Wait for frame capture (with timeout)
    let start = std::time::Instant::now();
    while !captured.load(Ordering::SeqCst) && start.elapsed() < Duration::from_secs(5) {
        std::thread::sleep(Duration::from_millis(10));
    }

    stream
        .stop_capture()
        .map_err(|e| anyhow::anyhow!("Failed to stop capture: {:?}", e))?;

    if !captured.load(Ordering::SeqCst) {
        anyhow::bail!("Capture timed out - no frames received. Make sure screen recording permission is granted.");
    }

    Ok(())
}

pub fn is_supported() -> bool {
    true
}

pub fn platform_name() -> &'static str {
    "macos"
}
