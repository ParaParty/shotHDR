use std::io;
use std::io::Write;
use std::sync::Arc;

use crate::api::screen_shot_api::CaptureResult;
use crate::frb_generated::StreamSink;
use windows_capture::capture::Context;
use windows_capture::capture::GraphicsCaptureApiHandler;
use windows_capture::frame::Frame;
use windows_capture::graphics_capture_api::InternalCaptureControl;
use windows_capture::monitor::Monitor;
use windows_capture::settings::{
    ColorFormat, CursorCaptureSettings, DirtyRegionSettings, DrawBorderSettings,
    MinimumUpdateIntervalSettings, SecondaryWindowSettings, Settings,
};

use windows::Win32::Graphics::Gdi::{MonitorFromPoint, MONITOR_DEFAULTTOPRIMARY};
use windows::Win32::UI::WindowsAndMessaging::{GetCursorPos, POINT};

pub struct Capture {
    flags: Option<CaptureFlags>,
}

pub struct CaptureFlags {
    pub mode: String,
    pub stream_sink: Arc<StreamSink<CaptureResult>>,
}

impl GraphicsCaptureApiHandler for Capture {
    type Flags = CaptureFlags;
    type Error = anyhow::Error;

    fn new(ctx: Context<Self::Flags>) -> Result<Self, Self::Error> {
        Ok(Self {
            flags: Some(ctx.flags),
        })
    }

    fn on_frame_arrived(
        &mut self,
        frame: &mut Frame,
        capture_control: InternalCaptureControl,
    ) -> Result<(), Self::Error> {
        io::stdout().flush()?;
        capture_control.stop();
        let buffer = frame.buffer().unwrap();
        let frame_width = buffer.width();
        let frame_height = buffer.height();
        let raw_buffer = buffer.as_raw_buffer();
        let flags = self.flags.as_ref().unwrap();
        let capture_result = CaptureResult {
            mode: flags.mode.clone(),
            raw_data: raw_buffer.to_vec(),
            frame_width,
            frame_height,
        };
        flags.stream_sink.add(capture_result).unwrap();
        Ok(())
    }

    fn on_closed(&mut self) -> Result<(), Self::Error> {
        println!("Capture Session Closed");
        Ok(())
    }
}

pub fn take_full_screen_internal(stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    let stream_sink_arc = Arc::from(stream_sink);

    // Find the monitor that contains the mouse cursor
    let mut point = POINT::default();
    unsafe {
        GetCursorPos(&mut point)
            .map_err(|e| anyhow::anyhow!("Failed to get cursor pos: {:?}", e))?
    };

    let hmonitor = unsafe { MonitorFromPoint(point, MONITOR_DEFAULTTOPRIMARY) };

    let monitors = Monitor::enumerate()
        .map_err(|e| anyhow::anyhow!("Failed to enumerate monitors: {:?}", e))?;
    if monitors.is_empty() {
        anyhow::bail!("No monitors found");
    }

    // Find the monitor corresponding to the HMONITOR from cursor position
    let target_monitor = monitors
        .iter()
        .find(|m| m.as_raw_hmonitor() as isize == hmonitor.0 as isize)
        .unwrap_or(&monitors[0]);

    let settings = Settings::new(
        target_monitor.clone(),
        CursorCaptureSettings::WithCursor,
        DrawBorderSettings::WithBorder,
        SecondaryWindowSettings::CaptureAll,
        MinimumUpdateIntervalSettings::Default,
        DirtyRegionSettings::Default,
        ColorFormat::Rgba16F,
        CaptureFlags {
            stream_sink: stream_sink_arc.clone(),
            mode: "full_screen".to_string(),
        },
    );

    Capture::start(settings).expect("Screen Capture Failed");
    Ok(())
}

pub fn is_supported() -> bool {
    true
}

pub fn platform_name() -> &'static str {
    "windows"
}
