use clap::{arg, value_parser, ArgAction, Command};
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;

use dotenv_parser::parse_dotenv;
use home::home_dir;

use base64::{engine::general_purpose, Engine as _};

use crypto::buffer::{BufferResult, ReadBuffer, WriteBuffer};
use crypto::{aes, blockmodes, buffer, symmetriccipher};

static PREFIX: &str = "__ENCRYPTED__:";

/// Returns decrypt key from ~/.envrc for env_name
///
/// ~/.envrc contains all the AES key for different environment
/// local=xxx
/// test=xxx
///
fn read_secret(env_name: &str) -> Result<String, String> {
    // read .envrc file to get AES key
    let envrc: String = fs::read_to_string(home_dir().unwrap().join(".envrc")).unwrap();
    let keys = parse_dotenv(&envrc).unwrap();

    match keys.get(env_name) {
        Some(key) => {
            if key.to_string().is_empty() {
                Err(format!("Empty secrety key for env: {env_name}"))
            } else {
                Ok(key.to_string())
            }
        }
        None => Err(format!("Cannot find key for env: {env_name}")),
    }
}

/// Decrypt one value using AES
///
fn decrypt_value(
    secret: &str,
    value: &str,
) -> Result<String, symmetriccipher::SymmetricCipherError> {
    let secret_bytes = secret.as_bytes();
    let key = &secret_bytes[0..32];
    let iv = &secret_bytes[32..48];

    let input = general_purpose::STANDARD_NO_PAD.decode(value).unwrap();

    // AES decryptor
    let mut decryptor =
        aes::cbc_decryptor(aes::KeySize::KeySize256, key, iv, blockmodes::PkcsPadding);

    let mut final_result = Vec::<u8>::new();
    let mut read_buffer = buffer::RefReadBuffer::new(&input);
    let mut buffer = [0; 512];
    let mut write_buffer = buffer::RefWriteBuffer::new(&mut buffer);

    loop {
        let result = decryptor.decrypt(&mut read_buffer, &mut write_buffer, true)?;
        final_result.extend(
            write_buffer
                .take_read_buffer()
                .take_remaining()
                .iter()
                .map(|&i| i),
        );
        match result {
            BufferResult::BufferUnderflow => break,
            BufferResult::BufferOverflow => {}
        }
    }

    let result = String::from_utf8(final_result).unwrap();

    Ok(result)
}

/// Encrypt one value using AES
///
fn encrypt_value(
    secret: &str,
    value: &str,
) -> Result<String, symmetriccipher::SymmetricCipherError> {
    let secret_bytes = secret.as_bytes();
    let key = &secret_bytes[0..32];
    let iv = &secret_bytes[32..48];

    let input = value.as_bytes();

    // AES encryptor
    let mut encryptor =
        aes::cbc_encryptor(aes::KeySize::KeySize256, key, iv, blockmodes::PkcsPadding);

    let mut final_result = Vec::<u8>::new();
    let mut read_buffer = buffer::RefReadBuffer::new(&input);
    let mut buffer = [0; 512];
    let mut write_buffer = buffer::RefWriteBuffer::new(&mut buffer);

    loop {
        let result = encryptor.encrypt(&mut read_buffer, &mut write_buffer, true)?;
        final_result.extend(
            write_buffer
                .take_read_buffer()
                .take_remaining()
                .iter()
                .map(|&i| i),
        );
        match result {
            BufferResult::BufferUnderflow => break,
            BufferResult::BufferOverflow => {}
        }
    }

    Ok(PREFIX.to_string() + &general_purpose::STANDARD_NO_PAD.encode(final_result))
}

fn merge_env_files(
    secret: &str,
    input_files: &Vec<PathBuf>,
) -> Result<BTreeMap<String, String>, String> {
    let mut result: BTreeMap<String, String> = BTreeMap::new();

    // read each env file
    // decrypt and merge them into result
    for file_path in input_files {
        let content = fs::read_to_string(file_path).unwrap();
        let raw_env = parse_dotenv(&content).unwrap();

        for (key, value) in &raw_env {
            if result.contains_key(key) {
                return Err(format!("duplicated env: {key}"));
            }

            if value.starts_with(PREFIX) {
                let part = &value[PREFIX.len()..];
                result.insert(key.to_string(), decrypt_value(secret, part).unwrap());
            } else {
                result.insert(key.to_string(), value.to_string());
            }
        }
    }

    Ok(result)
}

fn main() {
    let matches = Command::new("env_compiler")
        .version("1.0")
        .arg(arg!(-e --env <VALUE> "Set current environment").required(true))
        .subcommand(
            Command::new("encrypt")
                .about("encrypt value")
                .arg(arg!(-v --value <VALUE> "value to be encrypted").required(true)),
        )
        .subcommand(
            Command::new("decrypt")
                .about("decrypt value")
                .arg(arg!(-v --value <VALUE> "value to be decrypted").required(true)),
        )
        .subcommand(
            Command::new("compile")
                .about("compile and merge .bzlenv files")
                .arg(
                    arg!(-o --output <FILE>)
                        .required(true)
                        .value_parser(value_parser!(PathBuf)),
                )
                .arg(
                    arg!(-i --input <FILE>)
                        .required(false)
                        .action(ArgAction::Append)
                        .value_parser(value_parser!(PathBuf)),
                ),
        )
        .get_matches();

    // read secret key from ~/.envrc
    let secret = read_secret(matches.get_one::<String>("env").expect("required")).unwrap();

    match matches.subcommand() {
        Some(("encrypt", sub_matches)) => {
            let output = encrypt_value(
                secret.as_str(),
                sub_matches.get_one::<String>("value").unwrap(),
            )
            .unwrap();

            println!(
                "encrypt {:?}: {:?}",
                sub_matches.get_one::<String>("value").unwrap(),
                output
            );
        }
        Some(("decrypt", sub_matches)) => {
            let output = decrypt_value(
                secret.as_str(),
                sub_matches.get_one::<String>("value").unwrap(),
            )
            .unwrap();

            println!(
                "decrypt {:?}: {:?}",
                sub_matches.get_one::<String>("value").unwrap(),
                output
            );
        }
        Some(("compile", sub_matches)) => {
            let file_paths = sub_matches
                .get_many::<PathBuf>("input")
                .unwrap_or_default()
                .map(|v| PathBuf::from(v))
                .collect::<Vec<_>>();

            let result = merge_env_files(secret.as_str(), &file_paths).unwrap();

            let mut output_content = String::new();
            for (key, value) in &result {
                output_content.push_str(key);
                output_content.push_str("=\"");
                output_content.push_str(value);
                output_content.push_str("\"\n");

                // println!("{:?}: {:?}", *key, *value);
            }
            fs::write(
                sub_matches.get_one::<PathBuf>("output").unwrap(),
                output_content,
            )
            .unwrap();
        }
        _ => unreachable!("Subcommand is not supported"),
    }
}
