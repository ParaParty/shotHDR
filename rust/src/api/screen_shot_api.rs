use crate::frb_generated::StreamSink;

#[derive(Clone)]
pub struct CaptureResult {
    pub mode: String,
    pub raw_data: Vec<u8>,
    pub frame_width: u32,
    pub frame_height: u32,
}

impl CaptureResult {
    pub fn to_ultra_hdr_jpeg(&self) -> anyhow::Result<Vec<u8>> {
        crate::colorist::raw_buffer_to_ultra_hdr_jpeg(
            self.raw_data.clone(),
            self.frame_width,
            self.frame_height,
            &self.mode,
        )
    }

    /// Crop the capture result to specific region
    pub fn crop(&self, x: u32, y: u32, width: u32, height: u32) -> anyhow::Result<CaptureResult> {
        let bpp = 8; // Both Windows (Rgba16F) and macOS (RGhA) are 64-bit (8 bytes) per pixel currently

        // Basic bounds check
        if x + width > self.frame_width || y + height > self.frame_height {
            anyhow::bail!(
                "Crop out of bounds: crop({x},{y},{width},{height}) vs frame({}x{})",
                self.frame_width,
                self.frame_height
            );
        }

        let stride = (self.frame_width * bpp) as usize;
        let crop_stride = (width * bpp) as usize;
        let mut new_data = Vec::with_capacity(crop_stride * height as usize);

        for row in 0..height {
            let src_y = y + row;
            let src_start = (src_y as usize * stride) + (x as usize * bpp as usize);
            let src_end = src_start + crop_stride;
            new_data.extend_from_slice(&self.raw_data[src_start..src_end]);
        }

        Ok(CaptureResult {
            mode: self.mode.clone(),
            raw_data: new_data,
            frame_width: width,
            frame_height: height,
        })
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
