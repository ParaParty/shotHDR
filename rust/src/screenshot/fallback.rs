use crate::api::types::CaptureResult;
use crate::frb_generated::StreamSink;

pub fn take_full_screen_internal(_stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    anyhow::bail!("Screen capture not supported on this platform")
}

pub fn is_supported() -> bool {
    false
}

pub fn platform_name() -> &'static str {
    "unknown"
}
