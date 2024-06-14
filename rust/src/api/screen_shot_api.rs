use std::io;
use std::io::Write;
use std::sync::Arc;

use windows_capture::capture::GraphicsCaptureApiHandler;
use windows_capture::frame::Frame;
use windows_capture::graphics_capture_api::InternalCaptureControl;
use windows_capture::monitor::Monitor;
use windows_capture::settings::{ColorFormat, CursorCaptureSettings, DrawBorderSettings, Settings};

use crate::colorist;
use crate::frb_generated::StreamSink;

struct Capture {
    flags: Option<CaptureFlags>,
}

struct CaptureFlags {
    mode: String,
    stream_sink: Arc<StreamSink<CaptureResult>>,
}

pub struct CaptureResult {
    pub mode: String,
    pub raw_data: Vec<u8>,
    pub frame_width: u32,
    pub frame_height: u32,
}

impl CaptureResult {
    pub fn to_avif(&self) -> anyhow::Result<Vec<u8>> {
        colorist::raw_buffer_to_avif(self.raw_data.clone(), self.frame_width, self.frame_height)
    }
}

impl GraphicsCaptureApiHandler for Capture {
    // The type of flags used to get the values from the settings.
    type Flags = CaptureFlags;

    // The type of error that can occur during capture, the error will be returned from `CaptureControl` and `start` functions.
    type Error = anyhow::Error;

    // Function that will be called to create the struct. The flags can be passed from settings.
    fn new(message: Self::Flags) -> Result<Self, Self::Error> {
        Ok(Self {
            flags: Some(message),
        })
    }

    // Called every time a new frame is available.
    fn on_frame_arrived(
        &mut self,
        frame: &mut Frame,
        capture_control: InternalCaptureControl,
    ) -> Result<(), Self::Error> {
        io::stdout().flush()?;
        capture_control.stop();
        let mut buffer = frame.buffer().unwrap();
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

    // Optional handler called when the capture item (usually a window) closes.
    fn on_closed(&mut self) -> Result<(), Self::Error> {
        println!("Capture Session Closed");
        Ok(())
    }
}

pub fn take_full_screen(stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    let stream_sink_arc = Arc::from(stream_sink);
    let primary_monitor = Monitor::primary()?;
    let settings = Settings::new(
        primary_monitor,
        CursorCaptureSettings::WithCursor,
        DrawBorderSettings::WithBorder,
        ColorFormat::Rgba16F,
        CaptureFlags {
            stream_sink: stream_sink_arc.clone(),
            mode: "full_screen".to_string(),
        },
    );
    Capture::start(settings).expect("Screen Capture Failed");
    Ok(())
}