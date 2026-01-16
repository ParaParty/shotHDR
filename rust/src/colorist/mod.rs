//! Color processing and HDR encoding utilities
//!
//! This module handles the conversion of raw HDR screen capture data to
//! Ultra HDR JPEG format which is compatible with Android's UltraHDR standard.

use anyhow::anyhow;
use glam::f32::{Mat3, Vec3};
use half::prelude::*;
use ultrahdr::{sys, Encoder, ImgLabel, RawImage};

/// Convert half-float scRGB linear values to PQ (Perceptual Quantizer) values
fn linear_to_pq(linear: f32) -> f32 {
    let pow_linear = linear.powf(0.1593017578125f32);
    let num = 0.1640625f32 * pow_linear - 0.1640625f32;
    let den = 1.0f32 + 18.6875f32 * pow_linear;
    (1.0f32 + num / den).powf(78.84375f32)
}

/// scRGB to BT.2020 color matrix
const SRGB_TO_BT2100: [f32; 9] = [
    0.627409, 0.0691248, 0.0164234, 0.32926, 0.919549, 0.0880478, 0.0432719, 0.0113208, 0.895617,
];

/// Convert raw Rgba16F buffer from Windows Graphics Capture to Ultra HDR JPEG
///
/// The input buffer is in scRGB format (linear, extended range) with FP16 components.
/// We convert it to:
/// 1. SDR base image (8-bit sRGB JPEG)
/// 2. HDR gain map that allows reconstruction of HDR content
///
/// The output is a backwards-compatible JPEG that displays correctly on SDR screens
/// but contains HDR information for HDR-capable displays.
pub fn raw_buffer_to_ultra_hdr_jpeg(
    buf: Vec<u8>,
    frame_width: u32,
    frame_height: u32,
    mode: &str,
) -> anyhow::Result<Vec<u8>> {
    let width = frame_width as usize;
    let height = frame_height as usize;
    let num_pixels = width * height;

    let mut f32_data = vec![0.0f32; num_pixels * 4];

    if mode == "sdr_macos" {
        // BGRA 8-bit input
        // Convert to Linear scRGB (f32)
        if buf.len() != num_pixels * 4 {
            return Err(anyhow::anyhow!("Invalid buffer size for sdr_macos (BGRA)"));
        }

        for (i, chunk) in buf.chunks_exact(4).enumerate() {
            let b = chunk[0] as f32 / 255.0;
            let g = chunk[1] as f32 / 255.0;
            let r = chunk[2] as f32 / 255.0;
            let a = chunk[3] as f32 / 255.0;

            // Simple approximate Linearize (sRGB -> Linear)
            // Ideally use exact sRGB curve, but pow(2.2) is close enough for this context
            let r_lin = r.powf(2.2);
            let g_lin = g.powf(2.2);
            let b_lin = b.powf(2.2);

            f32_data[i * 4] = r_lin;
            f32_data[i * 4 + 1] = g_lin;
            f32_data[i * 4 + 2] = b_lin;
            f32_data[i * 4 + 3] = a;
        }
    } else {
        // Assume hdr_macos or other F16 input
        // Convert FP16 bytes to f16 values
        let f16_data: Vec<f16> = buf
            .chunks_exact(2)
            .map(|chunk| {
                let mut bytes_array = [0u8; 2];
                bytes_array.copy_from_slice(chunk);
                f16::from_le_bytes(bytes_array)
            })
            .collect();

        if f16_data.len() != num_pixels * 4 {
            // If buffer size mismatch, we might be reading garbage or stride issue
            // But let's try to proceed or error
        }

        f16_data.convert_to_f32_slice(&mut f32_data);
    }

    // Create SDR buffer (8-bit RGBA for the base layer)
    let mut sdr_rgba = vec![0u8; num_pixels * 4];

    // Create HDR buffer (10-bit in RGBA1010102 packed format for gain map)
    let mut hdr_rgba1010102 = vec![0u8; num_pixels * 4];

    let srgb_to_bt2100 = Mat3::from_cols_array(&SRGB_TO_BT2100);

    for (i, pixel) in f32_data.chunks_exact(4).enumerate() {
        let r = pixel[0];
        let g = pixel[1];
        let b = pixel[2];
        let a = pixel[3];

        // SDR: Output sRGB 8-bit
        // The input from macOS HDRCanonicalDisplay (RGhA) appears to be already gamma-encoded (sRGB/DisplayP3).
        // Using it directly for SDR ensures correct brightness. Applying gamma again causes "washed out" look.
        let sdr_r = r.clamp(0.0, 1.0);
        let sdr_g = g.clamp(0.0, 1.0);
        let sdr_b = b.clamp(0.0, 1.0);

        let sdr_offset = i * 4;
        sdr_rgba[sdr_offset] = (sdr_r * 255.0) as u8;
        sdr_rgba[sdr_offset + 1] = (sdr_g * 255.0) as u8;
        sdr_rgba[sdr_offset + 2] = (sdr_b * 255.0) as u8;
        sdr_rgba[sdr_offset + 3] = (a.clamp(0.0, 1.0) * 255.0) as u8;

        // HDR: Convert to BT.2020 PQ for HDR layer
        // Since input is treated as Gamma-Encoded, we must linearize it first for the HDR Math
        let lin_r = if r > 0.0 { r.powf(2.2) } else { 0.0 };
        let lin_g = if g > 0.0 { g.powf(2.2) } else { 0.0 };
        let lin_b = if b > 0.0 { b.powf(2.2) } else { 0.0 };

        let sc_rgb = Vec3::new(lin_r, lin_g, lin_b);
        const REC2100_MAX: f32 = 10000.0;
        const SDR_WHITE: f32 = 203.0; // Standard HDR reference white is often 203 nits (ITU-R BT.2408)

        // Scale to absolute brightness (assuming 1.0 = SDR White)
        let linear_absolute = sc_rgb * SDR_WHITE;
        let linear_normalized_bt2100 = linear_absolute / REC2100_MAX;

        // Convert Color Space (sRGB Primaries -> BT.2020 Primaries)
        // Note: If input is Display P3, we should use P3->BT2020 matrix, but assuming sRGB primaries for now.
        let linear_bt2100 = srgb_to_bt2100
            .mul_vec3(linear_normalized_bt2100)
            .clamp(Vec3::splat(0f32), Vec3::splat(1f32));

        let pq_r = linear_to_pq(linear_bt2100.x);
        let pq_g = linear_to_pq(linear_bt2100.y);
        let pq_b = linear_to_pq(linear_bt2100.z);

        // Pack as 10-bit per channel (values 0-1023)
        let r10 = (pq_r * 1023.0).round() as u32;
        let g10 = (pq_g * 1023.0).round() as u32;
        let b10 = (pq_b * 1023.0).round() as u32;
        let a2 = ((a.clamp(0.0, 1.0) * 3.0).round() as u32).min(3);

        // RGBA1010102 format: R[9:0] | G[9:0] | B[9:0] | A[1:0]
        let packed = r10 | (g10 << 10) | (b10 << 20) | (a2 << 30);
        let hdr_offset = i * 4;
        hdr_rgba1010102[hdr_offset..hdr_offset + 4].copy_from_slice(&packed.to_ne_bytes());
    }

    // Use ultrahdr to encode
    let mut encoder = Encoder::new().map_err(|e| anyhow!("Failed to create encoder: {:?}", e))?;

    // Create SDR raw image (base layer) using rgba8888
    let mut sdr_image = RawImage::rgba8888(
        width as u32,
        height as u32,
        &mut sdr_rgba,
        sys::uhdr_color_gamut::UHDR_CG_BT_709,
        sys::uhdr_color_transfer::UHDR_CT_SRGB,
        sys::uhdr_color_range::UHDR_CR_FULL_RANGE,
    )
    .map_err(|e| anyhow!("Failed to create SDR image: {:?}", e))?;

    // Create HDR raw image (gain map source) using packed format
    let mut hdr_image = RawImage::packed(
        sys::uhdr_img_fmt::UHDR_IMG_FMT_32bppRGBA1010102,
        width as u32,
        height as u32,
        &mut hdr_rgba1010102,
        sys::uhdr_color_gamut::UHDR_CG_BT_2100,
        sys::uhdr_color_transfer::UHDR_CT_PQ,
        sys::uhdr_color_range::UHDR_CR_FULL_RANGE,
    )
    .map_err(|e| anyhow!("Failed to create HDR image: {:?}", e))?;

    // Set images for encoding
    encoder
        .set_raw_image(&mut sdr_image, ImgLabel::UHDR_SDR_IMG)
        .map_err(|e| anyhow!("Failed to set SDR image: {:?}", e))?;
    encoder
        .set_raw_image(&mut hdr_image, ImgLabel::UHDR_HDR_IMG)
        .map_err(|e| anyhow!("Failed to set HDR image: {:?}", e))?;

    // Set output format
    encoder
        .set_output_format(sys::uhdr_codec::UHDR_CODEC_JPG)
        .map_err(|e| anyhow!("Failed to set output format: {:?}", e))?;

    // Set quality (0-100)
    encoder
        .set_quality(95, ImgLabel::UHDR_BASE_IMG)
        .map_err(|e| anyhow!("Failed to set base quality: {:?}", e))?;
    encoder
        .set_quality(95, ImgLabel::UHDR_GAIN_MAP_IMG)
        .map_err(|e| anyhow!("Failed to set gain map quality: {:?}", e))?;

    // Encode
    encoder
        .encode()
        .map_err(|e| anyhow!("Failed to encode: {:?}", e))?;

    // Get output bytes
    let output = encoder
        .encoded_stream()
        .ok_or_else(|| anyhow!("No encoded output"))?;
    let bytes = output
        .bytes()
        .map_err(|e| anyhow!("Failed to get bytes: {:?}", e))?;

    Ok(bytes.to_vec())
}
