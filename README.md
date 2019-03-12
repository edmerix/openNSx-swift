# openNSx in Swift

An object-oriented approach to dealing with neural data stored in Blackrock's NSx files, for substantially speedier reading of header and/or raw data in Swift projects.

## Usage

Example usage is given in ExampleFileRead.swift
Briefly:
```swift
let raw = openNSx()
raw.open(fileName: "~/Data/exampleFile.ns5")

// what time did the file start?
print("File start in local time: \(raw.startTimeFormatted)")

// read in a channel:
let data = raw.readChannel(chan: 41)

// and away you go with your analyses or plotting...
```
