//! Fails the build if this workspace grows a spend, send, or seed command.

use std::fs;
use std::path::Path;

#[test]
fn no_spend_surface() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let mut failures = Vec::new();
    for relative in [
        "zecbooks-core/src",
        "zecbooks-sync/src",
        "zecbooks-cli/src",
        "zecbooks-core/Cargo.toml",
        "zecbooks-sync/Cargo.toml",
        "zecbooks-cli/Cargo.toml",
        "Cargo.toml",
    ] {
        let path = root.join(relative);
        if path.is_dir() {
            scan_dir(&path, &mut failures);
        } else {
            scan_file(&path, &mut failures);
        }
    }
    assert!(
        failures.is_empty(),
        "spend surface is forbidden:\n{}",
        failures.join("\n")
    );
}

fn scan_dir(dir: &Path, failures: &mut Vec<String>) {
    let entries = fs::read_dir(dir).unwrap();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            scan_dir(&path, failures);
        } else if path.extension().and_then(|ext| ext.to_str()) == Some("rs")
            || path.extension().and_then(|ext| ext.to_str()) == Some("toml")
        {
            scan_file(&path, failures);
        }
    }
}

fn scan_file(path: &Path, failures: &mut Vec<String>) {
    let text = fs::read_to_string(path).unwrap_or_default();
    let visible = strip_tests(&text);
    let needles = [
        concat!("zcash_client_backend::", "proposal"),
        concat!("zcash_client_backend::", "fees"),
        concat!("propose_", "transfer"),
        concat!("create_", "proposed_transactions"),
        concat!("transparent-", "inputs"),
        "pczt",
    ];
    for needle in needles {
        if visible.contains(needle) {
            failures.push(format!("{} contains {needle}", path.display()));
        }
    }
    if path.ends_with("main.rs") {
        for command in ["Send", "Shield", "Spend", "Seed"] {
            if visible.contains(&format!("{command} {{")) {
                failures.push(format!("{} exposes {command}", path.display()));
            }
        }
    }
}

fn strip_tests(text: &str) -> String {
    let mut out = String::new();
    let mut rest = text;
    while let Some(index) = rest.find("#[cfg(test)]") {
        out.push_str(&rest[..index]);
        rest = &rest[index..];
        if let Some(end) = matching_module_end(rest) {
            rest = &rest[end..];
        } else {
            break;
        }
    }
    out.push_str(rest);
    out
}

fn matching_module_end(text: &str) -> Option<usize> {
    let brace = text.find('{')?;
    let mut depth = 0i32;
    for (offset, ch) in text[brace..].char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    return Some(brace + offset + 1);
                }
            }
            _ => {}
        }
    }
    None
}
