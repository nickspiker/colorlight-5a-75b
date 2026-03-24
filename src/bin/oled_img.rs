// oled_img — Floyd-Steinberg dither an image to 128×64 1bpp OLED .mem file
//
// Output: 1024 bytes packed in OLED page format.
// Page P (0-7), column C: byte = rom[P*128 + C], bit b = pixel at (C, P*8+b)
// bit 0 = top of page, bit 7 = bottom of page.
//
// Usage: oled_img <input_image> <output.mem>

use image::imageops;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: oled_img <input_image> <output.mem>");
        std::process::exit(1);
    }

    let img = image::open(&args[1]).expect("failed to open image");
    let img = img.resize_exact(128, 64, imageops::FilterType::Lanczos3);
    let luma = img.to_luma8();

    // Floyd-Steinberg dithering on f32 buffer
    let mut buf: Vec<f32> = luma.pixels().map(|p| p[0] as f32).collect();

    for y in 0..64usize {
        for x in 0..128usize {
            let old = buf[y * 128 + x].clamp(0.0, 255.0);
            let new = if old >= 128.0 { 255.0 } else { 0.0 };
            buf[y * 128 + x] = new;
            let err = old - new;
            if x + 1 < 128 { buf[y * 128 + x + 1]       += err * 7.0 / 16.0; }
            if y + 1 < 64 {
                if x > 0   { buf[(y+1) * 128 + x - 1]    += err * 3.0 / 16.0; }
                              buf[(y+1) * 128 + x]         += err * 5.0 / 16.0;
                if x + 1 < 128 { buf[(y+1) * 128 + x + 1] += err * 1.0 / 16.0; }
            }
        }
    }

    // Pack into OLED page format: 8 pages × 128 bytes
    let mut rom = vec![0u8; 1024];
    for y in 0..64usize {
        for x in 0..128usize {
            if buf[y * 128 + x] >= 128.0 {
                let page = y / 8;
                let bit  = y % 8;
                rom[page * 128 + x] |= 1 << bit;
            }
        }
    }

    let hex: String = rom.iter().map(|b| format!("{:02x}\n", b)).collect();
    std::fs::write(&args[2], hex).expect("failed to write");
    println!("wrote {}", args[2]);
}
