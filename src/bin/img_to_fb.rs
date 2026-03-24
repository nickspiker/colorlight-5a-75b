// img_to_fb — convert image to 8bpp grayscale framebuffer .mem
//
// Output: 8192 hex bytes, one per line, row-major order.
// addr = row*128 + col  (row 0 = top, col 0 = left)
// Used by top_oled_image.v — TRNG hardware dithering compares each
// byte against a random threshold at runtime to produce 1bpp output.
//
// Usage: img_to_fb <input_image> <output.mem>

use image::imageops;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: img_to_fb <input_image> <output.mem>");
        std::process::exit(1);
    }

    let img = image::open(&args[1]).expect("failed to open image");
    // Center-crop to 128×64, preserving aspect ratio (no squish)
    let (sw, sh) = (img.width(), img.height());
    let scale = (128.0 / sw as f64).max(64.0 / sh as f64);
    let nw = (sw as f64 * scale).ceil() as u32;
    let nh = (sh as f64 * scale).ceil() as u32;
    let img = img.resize_exact(nw, nh, imageops::FilterType::Lanczos3);
    let img = image::DynamicImage::from(
        imageops::crop_imm(&img, (nw - 128) / 2, (nh - 64) / 2, 128, 64).to_image()
    );
    let luma = img.to_luma8();

    let hex: String = luma.pixels().map(|p| format!("{:02x}\n", p[0])).collect();
    std::fs::write(&args[2], &hex).expect("failed to write");
    eprintln!("Written {}  (128×64 grayscale, row-major)", args[2]);
}
