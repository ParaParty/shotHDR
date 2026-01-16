pub use crate::api::screen_shot_api::CaptureResult;

use crate::frb_generated::StreamSink;

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
use windows as platform;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
use macos as platform;

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "linux")]
use linux as platform;

#[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
mod fallback;
#[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
use fallback as platform;

pub fn take_full_screen(stream_sink: StreamSink<CaptureResult>) -> anyhow::Result<()> {
    platform::take_full_screen_internal(stream_sink)
}

pub fn is_supported() -> bool {
    platform::is_supported()
}

pub fn platform_name() -> String {
    platform::platform_name().to_string()
}
