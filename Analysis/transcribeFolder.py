#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Feb 13 16:36:35 2025

@author: brandon
"""

import whisper
import os
import csv
import re
from tkinter import Tk
from tkinter.filedialog import askdirectory

# Get filenames
# audioFile = "test.wav"
# textFile = "results.txt"

model = whisper.load_model("turbo")

def process_file(audioFile):
    

    # load audio and pad/trim it to fit 30 seconds
    audio = whisper.load_audio(audioFile)
    audio = whisper.pad_or_trim(audio)

    # make log-Mel spectrogram and move to the same device as the model
    mel = whisper.log_mel_spectrogram(audio, n_mels=model.dims.n_mels).to(model.device)

    # detect the spoken language
    _, probs = model.detect_language(mel)
    print(f"Detected language: {max(probs, key=probs.get)}")

    # decode the audio
    options = whisper.DecodingOptions()
    result = whisper.decode(model, mel, options)

    # print the recognized text to the command window
    print(result.text)

    # Export text as variable
    return result.text
# end function process_file

# Action stage: loop over every file in the input folder
# Prompt for input and output folders
Tk().withdraw() # Hide the main Tk window to prevent screen flash where it appears then disappears
inputFolder = askdirectory(title='Select Input Folder (audio files)') # shows dialog box
outputFolder = askdirectory(title='Select Output Folder (csv files)')

# Group data by subject ID
subject_data = {}

for filename in os.listdir(inputFolder):
    if not filename.endswith(".wav"):
        continue

    filepath = os.path.join(inputFolder, filename)
    base = os.path.splitext(filename)[0]

    # Split and parse the filename
    try:
        parts = base.split('-')
        subject_id = parts[0]             # "TC_64"
        trial_number = int(parts[1])      # 23
        # Search for 'Q' followed by digits anywhere in the filename
        # (using regex bc it might be -Q65 or it might be -f_Q65 for flipped)
        match = re.search(r'Q(\d+)', base)
        if not match:
            raise ValueError("No animation ID found in filename")
        anim_id = int(match.group(1))  # extract the digits after 'Q'
    except Exception as e:
        print(f"Filename parse failed for {filename}: {e}")
        continue

    # Transcribe
    print(f"Processing: {filename}")
    transcription = process_file(filepath)

    # Prepare row
    row = [trial_number, anim_id, transcription]

    # Append to subject's list
    # if subject_id not in subject_data:
    #     subject_data[subject_id] = []
    # subject_data[subject_id].append(row)
    subject_data.setdefault(subject_id, []).append(row)

# Write CSVs
for subject_id, rows in subject_data.items():
    output_path = os.path.join(output_folder, f"{subject_id}.csv")
    with open(output_path, "w", newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(["trial", "animation_id", "transcription"])
        for row in sorted(rows):  # sort by trial number if you want
            writer.writerow(row)

print("Done.")