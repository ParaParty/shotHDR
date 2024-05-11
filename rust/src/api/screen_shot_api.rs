use std::io;
use std::io::Write;
use std::sync::Arc;

use anyhow::anyhow;
use half::f16;
use libavif_sys::{AVIF_CHROMA_SAMPLE_POSITION_UNKNOWN, AVIF_FALSE, AVIF_PIXEL_FORMAT_YUV420, AVIF_RANGE_FULL, AVIF_RANGE_LIMITED, AVIF_RESULT_OK, avifBool, avifEncoderCreate, avifEncoderWrite, avifImage, avifRWData, avifRWDataFree};
use windows::Win32::Graphics::Dxgi;

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
        _raw_buffer_to_avif(self.raw_data.clone(), self.frame_width, self.frame_height)
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

fn _raw_buffer_to_avif(buf: Vec<u8>, frame_width: u32, frame_height: u32) -> anyhow::Result<Vec<u8>> {
    let data: Vec<f16> = buf.chunks_exact(2).map(|chunk| {
        let mut bytes_array = [0u8; 2];
        bytes_array.copy_from_slice(chunk);
        f16::from_le_bytes(bytes_array)
    }).collect();
    let display_desc = Dxgi::DXGI_OUTPUT_DESC1::default();
    let mut avif = avifImage::default();
    avif.width = frame_width;
    avif.height = frame_height;
    avif.depth = 10;
    avif.yuvFormat = AVIF_PIXEL_FORMAT_YUV420;
    avif.yuvRange = AVIF_RANGE_FULL;
    avif.yuvChromaSamplePosition = AVIF_CHROMA_SAMPLE_POSITION_UNKNOWN;
    avif.alphaPremultiplied = AVIF_FALSE as avifBool;
    let result = colorist::fill_avif_image(data, &display_desc, false, &mut avif);
    if result != AVIF_RESULT_OK {
        return Err(anyhow!("fill_avif_image failed: {}", result));
    }
    assert_eq!(result, AVIF_RESULT_OK);
    let avif_vec = unsafe {
        let encoder = avifEncoderCreate();
        (*encoder).speed = 12;
        (*encoder).quality = 100;
        (*encoder).maxThreads = 16;
        (*encoder).tileColsLog2 = 1;
        (*encoder).tileRowsLog2 = 1;
        let mut output = avifRWData::default();
        let output_c = &mut output as *mut avifRWData;
        let result = avifEncoderWrite(encoder, &avif, output_c);
        assert_eq!(result, AVIF_RESULT_OK);
        let data = std::slice::from_raw_parts(output.data, output.size).to_vec();
        avifRWDataFree(output_c);
        data
    };
    return Ok(avif_vec);
}