use std::cmp::max;
use glam::f32::{Mat3, Vec3};
use half::prelude::*;
use libavif_sys::*;
use windows::Win32::Graphics::Dxgi;

#[repr(C)]
#[derive(Clone, Copy, Debug)]
struct RGBA {
    r: u16,
    g: u16,
    b: u16,
    a: u16,
}

pub fn linear_to_pq(linear: f32) -> f32 {
    let pow_linear = linear.powf(0.1593017578125f32);
    let num = 0.1640625f32 * pow_linear - 0.1640625f32;
    let den = 1.0f32 + 18.6875f32 * pow_linear;
    (1.0f32 + num / den).powf(78.84375f32)
}

pub fn float_to_unorm(f: &[f32]) -> (RGBA, u16) {
    let sc_rgb = Vec3::new(f[0], f[1], f[2]);

    const REC2100_MAX: f32 = 10000.0;
    const SDR_WHITE: f32 = 80.0;
    let scale = SDR_WHITE / REC2100_MAX;
    let linear_srgb = sc_rgb * scale;

    let srgb_to_bt2100 = Mat3::from_cols_array(&[
        0.627409, 0.0691248, 0.0164234,
        0.32926, 0.919549, 0.0880478,
        0.0432719, 0.0113208, 0.895617
    ]);
    let linear_bt2100 = srgb_to_bt2100.mul_vec3(linear_srgb).clamp(Vec3::splat(0f32), Vec3::splat(1f32));

    let coeff = Vec3::new(0.2627, 0.6780, 0.0593);
    let brightness = (linear_bt2100.dot(coeff) * 10000f32).round() as u16;

    let pq_bt2100 = Vec3::from(linear_bt2100.as_ref().map(linear_to_pq));
    let rgb = (pq_bt2100 * 65535f32).round().as_u16vec3();

    (RGBA {
        r: rgb.x,
        g: rgb.y,
        b: rgb.z,
        a: (f[3] * 65535f32) as u16,
    }, brightness)
}

/// Fill AVIF Image from half float scRGB data.
///
/// The following fields of avif should be filled:
/// - width
/// - height
/// - depth
/// - yuvFormat
/// - yuvRange
/// - yuvChromaSamplePosition
/// - alphaPremultiplied
///
/// After call, avif owns pixel memory and should be freed with avifImageDestroy
///
/// For now display is not actually used.
/// It may be useful in the future.
pub fn fill_avif_image(data: Vec<f16>, display: &Dxgi::DXGI_OUTPUT_DESC1, alpha: bool, avif: &mut avifImage) -> avifResult {
    let num_pixel = avif.width as usize * avif.height as usize;
    assert_eq!(data.len(), num_pixel * 4);

    let mut f32_buf = vec![0.0; data.len()];
    data.convert_to_f32_slice(&mut f32_buf);

    let (mut u16_buf, brightness) : (Vec<RGBA>, Vec<u16>) = f32_buf.chunks_exact(4).map(float_to_unorm).unzip();
    let max_cll = *brightness.iter().max().unwrap();
    let sum: u64 = brightness.iter().map(|x| *x as u64).sum();
    let pall = ((sum as f64) / (num_pixel as f64)).round() as u16;

    let rgb = avifRGBImage {
        width: avif.width,
        height: avif.height,
        depth: 16,
        format: AVIF_RGB_FORMAT_RGBA,
        chromaUpsampling: AVIF_CHROMA_UPSAMPLING_AUTOMATIC,
        chromaDownsampling: AVIF_CHROMA_DOWNSAMPLING_BEST_QUALITY,
        avoidLibYUV: AVIF_FALSE as avifBool,
        ignoreAlpha: if alpha { AVIF_FALSE } else { AVIF_TRUE } as avifBool,
        alphaPremultiplied: AVIF_FALSE as avifBool,
        isFloat: AVIF_FALSE as avifBool,
        maxThreads: 1,
        pixels: u16_buf.as_mut_ptr() as *mut u8,
        rowBytes: avif.width * 8,
    };

    avif.colorPrimaries = AVIF_COLOR_PRIMARIES_BT2020 as avifColorPrimaries;
    avif.transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084 as avifTransferCharacteristics;
    avif.matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL as avifMatrixCoefficients;
    avif.clli = avifContentLightLevelInformationBox {
        maxCLL: max_cll,
        maxPALL: pall,
    };

    // TODO: fill avif.mdcv once supported by libavif
    _ = display;

    unsafe {
        let result = avifImageAllocatePlanes(avif, if alpha { AVIF_PLANES_ALL } else { AVIF_PLANES_YUV });
        if result != AVIF_RESULT_OK {
            return result;
        }
        avifImageRGBToYUV(avif, &rgb)
    }
}
