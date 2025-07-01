use std::fs::File;
use std::io::Read;

fn is_valid_ico(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    let mut file = File::open(path)?;
    let mut header = [0; 4];
    file.read_exact(&mut header)?;
    // ICO files start with 0x00 0x00 0x01 0x00
    Ok(header == [0, 0, 1, 0])
}

fn main() {
    let icon_path = "src-tauri/icons/icon.ico";
    
    match is_valid_ico(icon_path) {
        Ok(true) => {
            println!("✓ {} is a valid Windows ICO file", icon_path);
        }
        Ok(false) => {
            eprintln!("✗ {} is not a valid ICO file!", icon_path);
            std::process::exit(1);
        }
        Err(e) => {
            eprintln!("Error checking {}: {}", icon_path, e);
            std::process::exit(1);
        }
    }
}