use crate::frb_generated::StreamSink;

#[derive(Clone)]
pub struct CaptureResult {
    pub mode: String,
    pub raw_data: Vec<u8>,
    pub frame_width: u32,
    pub frame_height: u32,
}

impl CaptureResult {
    /// Convert raw HDR buffer to Ultra HDR JPEG format
    /// This produces a backwards-compatible JPEG with embedded HDR gain map
    pub fn to_ultra_hdr_jpeg(&self) -> anyhow::Result<Vec<u8>> {
        crate::colorist::raw_buffer_to_ultra_hdr_jpeg(
            self.raw_data.clone(),
            self.frame_width,
            self.frame_height,
            &self.mode,
        )
    }
}

/// Take a full screen HDR screenshot
pub fn take_full_screen(stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    crate::screenshot::take_full_screen(stream_sink)
}

/// Check if screen capture is supported on the current platform
pub fn is_screen_capture_supported() -> bool {
    crate::screenshot::is_supported()
}

/// Get the current platform name
pub fn get_platform_name() -> String {
    crate::screenshot::platform_name()
}
