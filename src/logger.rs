use colored::*;
use std::io;

pub fn setup_logger() -> Result<(), fern::InitError> {
    fern::Dispatch::new()
        .format(|out, message, record| {
            // Map log levels to specific colors
            let level_color = match record.level() {
                log::Level::Error => Color::Red,
                log::Level::Warn => Color::Yellow,
                log::Level::Info => Color::Green,
                log::Level::Debug => Color::Cyan,
                log::Level::Trace => Color::Magenta,
            };

            // Format: [LEVEL]: message
            out.finish(format_args!(
                "[{}] {}",
                record.level().to_string().color(level_color).bold(),
                message
            ))
        })
        .level(log::LevelFilter::Debug)
        .chain(io::stdout())
        .apply()?;
    Ok(())
}
