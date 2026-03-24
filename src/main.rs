// img2mem — convert an image to 3 greyscale bitplane .mem files for $readmemh
//
// Output: three files (grey0.mem, grey1.mem, grey2.mem), each 9600 bytes.
// Packed identical to ntsc_framebuf: 8 pixels per byte, MSB = leftmost pixel.
// grey0 = MSB (bit 2), grey1 = mid (bit 1), grey2 = LSB (bit 0).
//
// Usage: img2mem <input_image> <output_dir>
//   e.g. img2mem test.jpg build/

use image::imageops;
use std::fs;
use std::path::Path;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: img2mem <input_image> <output_dir>");
        std::process::exit(1);
    }

    let img = image::open(&args[1]).expect("failed to open image");
    let img = img.resize_exact(320, 240, imageops::FilterType::Lanczos3);
    let grey = imageops::flip_vertical(&img.to_luma8());

    // Quantize each pixel to 3 bits (0-7).
    // sRGB JPEG on a CRT (gamma ~2.2): the gamma roughly cancels, so linear
    // quantization of the 8-bit value looks correct.
    let pixels: Vec<u8> = grey.pixels().map(|p| p[0] >> 4).collect();

    // Pack into 4 bitplanes, each 9600 bytes (40 bytes × 240 rows, 8px/byte).
    // Pixel order within a byte: bit 7 = leftmost (fb_x % 8 == 0).
    let n = 320 * 240; // 76800 pixels
    assert_eq!(pixels.len(), n);

    let mut plane = [vec![0u8; 9600], vec![0u8; 9600], vec![0u8; 9600], vec![0u8; 9600]];

    for (i, &v) in pixels.iter().enumerate() {
        let byte_idx = i / 8;
        let bit_pos  = 7 - (i % 8);  // MSB = leftmost
        for b in 0..4usize {
            if (v >> (3 - b)) & 1 == 1 {
                plane[b][byte_idx] |= 1 << bit_pos;
            }
        }
    }

    let out_dir = Path::new(&args[2]);
    fs::create_dir_all(out_dir).expect("failed to create output dir");

    for (b, name) in ["grey0.mem", "grey1.mem", "grey2.mem", "grey3.mem"].iter().enumerate() {
        let hex: String = plane[b].iter()
            .map(|byte| format!("{:02x}\n", byte))
            .collect();
        let path = out_dir.join(name);
        fs::write(&path, hex).expect("failed to write mem file");
        println!("wrote {}", path.display());
    }
}
