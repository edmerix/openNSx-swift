/*  An example of how to read header info and data from NSx files using the openNSx class
    Note that unlike in the NPMK with Matlab, this is properly object-oriented, meaning
    we only truly store handles to the files, and then request specific data using methods
    on that object.
*/
import Cocoa

// "raw" will hold our object used for reading in data. At this point, no file is loaded into it
let raw = openNSx()

// use the "open" method to read in a file, specified by fileName:
raw.open(fileName: "~/Data/Patients/patientname/examplefilename.ns5")

// now we have access to the header details in the specified file, e.g.:
print("\n---Start time in UTC: \(raw.startTime)---")
print("---Start time formatted in local time: \(raw.startTimeFormatted)---")

// cool, let's actually read some data. No need to read all of it at once with this method, e.g. let's just read in channel 9's raw data:
let data = raw.readChannel(chan: 9)

print("Returned from data read")

// at this point the data has been loaded. Use this class within projects to allow for speedy loading of NSx data on the fly...
