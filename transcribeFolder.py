import whisper
import csv
import re
from pathlib import Path
from tkinter import Tk
from tkinter.filedialog import askdirectory

model = whisper.load_model("small")
pattern = re.compile(r'Q(\d+)')  # pre-compile regex

def process_file(audio_file: str) -> str:
    """Load audio, transcribe with Whisper, return transcription text."""
    audio = whisper.load_audio(audio_file)
    audio = whisper.pad_or_trim(audio)
    mel = whisper.log_mel_spectrogram(audio, n_mels=model.dims.n_mels).to(model.device)
    _, probs = model.detect_language(mel)
    print(f"Detected language: {max(probs, key=probs.get)}")
    result = whisper.decode(model, mel, whisper.DecodingOptions())
    return result.text

def write_csv(subject_id: str, rows: list, output_dir: Path) -> None:
    """Write transcriptions to CSV file for a given subject."""
    output_path = output_dir / f"{subject_id}.csv"
    with open(output_path, "w", newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(["trial", "animation_id", "transcription"])
        for row in sorted(rows):
            writer.writerow(row)

def main():
    Tk().withdraw()
    input_folder = Path(askdirectory(title="Select Input Folder (audio files)"))
    output_folder = Path(askdirectory(title="Select Output Folder (csv files)"))

    subject_data = {}

    for i, filepath in enumerate(input_folder.iterdir(), 1):
        if filepath.suffix.lower() != ".wav":
            continue

        base = filepath.stem
        try:
            parts = base.split("-")
            subject_identifier = parts[0]
            trial_num = int(parts[1])
            match = pattern.search(base)
            if not match:
                raise ValueError("No animation ID found in filename")
            anim_id = int(match.group(1))
        except ValueError as e:
            print(f"Filename parse failed for {filepath.name}: {e}")
            continue

        print(f"Processing file {i}: {filepath.name}")
        transcription = process_file(str(filepath))
        row = [trial_num, anim_id, transcription]
        subject_data.setdefault(subject_identifier, []).append(row)

    for subject_id, rows in subject_data.items():
        write_csv(subject_id, rows, output_folder)

    print("Done.")

if __name__ == "__main__":
    main()
