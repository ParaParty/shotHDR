use crate::api::screen_shot_api::CaptureResult;
use crate::frb_generated::StreamSink;

pub fn take_full_screen_internal(_stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    anyhow::bail!(
        "Linux screen capture not yet implemented. Consider using PipeWire or xdg-desktop-portal."
    )
}

pub fn is_supported() -> bool {
    false
}

pub fn platform_name() -> &'static str {
    "linux"
}
