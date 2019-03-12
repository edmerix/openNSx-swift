import Cocoa

public class openNSx: NSObject {
    
    private let extendedHeaderLength = 66
    private var extendedReadSize: Int = -1
    private var dataStartByte = [UInt64]()
    private var dataEndByte = [UInt64]()
    private var dataPoints = [UInt64]()
    private var dataStartStamps = [UInt32]()
    private var endOfHeader: UInt64 = 0
    private var pausedFile: Bool = false
    private var endOfFile: UInt64 = 0
    
    public var fileName: String!
    public var Fs: Double = 0.0
    public var channelCount = 0
    public var electrodeIDs = [Int]()
    public var electrodeLabels = [String]()
    public var electrodeUnits = [String]()
    public var fileTypeID: String = ""
    public var fileSpec: Double = 0.0
    public var startTime: [Int] = [0, 0, 0, 0, 0, 0, 0, 0]
    public var startTimeFormatted: String = ""
    
    public func open(fileName: String){
        self.fileName = fileName
        if let file: FileHandle = FileHandle(forReadingAtPath: self.fileName){
            file.seekToEndOfFile()
            endOfFile = file.offsetInFile
            file.seek(toFileOffset: 0)
            var buf = file.readData(ofLength: 8)
            if let string = String(data: buf, encoding: .utf8){
                fileTypeID = string
            }
            print("fileTypeID = \(fileTypeID)")
            switch fileTypeID{
            case "NEURALSG":
                fileSpec = 2.1
                print("File version 2.1 hasn't been coded yet. Returning.")
                file.closeFile()
                return
            case "NEURALCD":
                buf = file.readData(ofLength: 306)
                
                fileSpec = Double(buf[0]) + (Double(buf[1])/10)
                print("fileSpec = \(fileSpec)")

                let headerBytes = UInt32(littleEndian: buf[2...5].withUnsafeBytes({$0.pointee}))
                print("headerBytes = \(headerBytes)")
                var samplingLabel = ""
                if let string = String(data: buf[6...21], encoding: .utf8){
                     samplingLabel = string
                }
                print("samplingLabel = \(samplingLabel)")
                let commentSection = buf[22...277]
                let comment = (commentSection.withUnsafeBytes(String.init(utf8String:)))!
                print("comment = \(comment)")
                
                let timeRes = UInt32(littleEndian: buf[282...285].withUnsafeBytes({$0.pointee}))
                print("timeRes = \(timeRes)")
                Fs = Double(timeRes/UInt32(littleEndian: buf[278...281].withUnsafeBytes({$0.pointee})))
                print("Fs = \(Fs)")
                for i in 0..<8 {
                    let start = 286 + (i*2)
                    startTime[i] = Int(UInt16(littleEndian: buf[start...start+1].withUnsafeBytes({$0.pointee})))
                }
                
                startTime.remove(at: 2)
                let dateFormatIn = DateFormatter()
                dateFormatIn.locale = Locale(identifier: "en_GB")
                dateFormatIn.timeZone = TimeZone(abbreviation: "UTC")
                dateFormatIn.dateFormat = "YYYY MM dd HH mm ss SSS"
                let dateFormatOut = DateFormatter()
                dateFormatOut.locale = Locale(identifier: "en_US")
                dateFormatOut.timeZone = NSTimeZone.local // maybe set to TimeZone(abbreviation: "EST")
                dateFormatOut.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
                let d_str = startTime.map { String($0)}.joined(separator: " ")
                let time_in = dateFormatIn.date(from: d_str)
                startTimeFormatted = dateFormatOut.string(from: time_in!)
                
                print("startTime = \(startTime)")
                print("startTimeFormatted = \(startTimeFormatted)")
                
                channelCount = Int(UInt32(littleEndian: buf[302...305].withUnsafeBytes({$0.pointee})))
                print("channelCount = \(channelCount)")
                
                extendedReadSize = channelCount * extendedHeaderLength
                print("extendedReadSize = \(extendedReadSize)")
                
                buf = file.readData(ofLength: extendedReadSize)
                // need to code the extendedHeader bit here
                for hIdx in 0..<channelCount {
                    let offset = hIdx * extendedHeaderLength
                    let elecType = (buf[offset+0..<offset+2].withUnsafeBytes(String.init(utf8String:)))!
                    if elecType.prefix(2) != "CC" {
                        print("Electrode type does not support extended header")
                        file.closeFile()
                        return
                    }
                    // these are ugly:
                    electrodeIDs.append(Int(UInt16(littleEndian: buf[offset+2..<offset+4].withUnsafeBytes({$0.pointee}))))
                    electrodeLabels.append((buf[offset+4..<offset+20].withUnsafeBytes(String.init(utf8String:)))!)
                    electrodeUnits.append((buf[offset+30..<offset+46].withUnsafeBytes(String.init(utf8String:)))!)
                    /*
                    print("elecID: \(electrodeIDs[hIdx])")
                    print("elecLabel: \(electrodeLabels[hIdx])")
                    print("elecUnits: \(electrodeUnits[hIdx])")
                    */
                }
                
            default:
                print("Unknown file spec: \(fileTypeID)")
                file.closeFile()
                return
            }
            
            endOfHeader = (file.offsetInFile)
            print("endOfHeader = \(endOfHeader)")
            
            // read stuff
            if fileTypeID == "NEURALSG" {
                dataStartByte.append(endOfHeader)
                file.seekToEndOfFile()
                dataPoints.append((file.offsetInFile-dataStartByte[0])/UInt64(channelCount*2))
            }else if fileTypeID == "NEURALCD" {
                var segment = -1
                while(file.offsetInFile < endOfFile){
                    print("offsetInFile: \(file.offsetInFile) of \(endOfFile)")
                    var buf = file.readData(ofLength: 1)
                    if buf[0] != 1 {
                        print("buf[0] isn't 1, bodging the total datapoint calculation")
                        dataPoints[segment] = (endOfFile - endOfHeader)/UInt64(channelCount*2)
                        break
                    }else{
                        segment += 1
                        buf = file.readData(ofLength: 8) // this might be wrong. Might need to read 8 for both dataStartStamps and then another 8 for dataPoints. But wait, no. Double check!
                        dataStartStamps.append(UInt32(littleEndian: buf[0..<4].withUnsafeBytes({$0.pointee})))
                        print("dataStartStamps[\(segment)] = \(dataStartStamps[segment])")
                        dataPoints.append(UInt64(UInt32(littleEndian: buf[4..<8].withUnsafeBytes({$0.pointee}))))
                        print("dataPoints[\(segment)] = \(dataPoints[segment])")
                        
                        dataStartByte.append(file.offsetInFile)
                        print("dataStartByte[\(segment)] = \(dataStartByte[segment])")
                        let seekPoint = file.offsetInFile + (dataPoints[segment] * UInt64(channelCount * 2))
                        if seekPoint > endOfFile {
                            dataEndByte.append(endOfFile)
                            file.seekToEndOfFile()
                        }else{
                            file.seek(toFileOffset: seekPoint)
                            dataEndByte.append(file.offsetInFile)
                        }
                        print("dataEndByte[\(segment)] = \(dataEndByte[segment])")
                        // ((dataEndByte - dataStartByte)/dataPoints)/2 = channelCount
                        // ((2822115-1379)/88148)/2 = 16
                    }
                }
            }else{
                print("Don't know how we ended up here; should have already panicked and left if not NEURALSG or NEURALCD")
                file.closeFile()
                return
            }
            if dataPoints.count > 1 {
                pausedFile = true
            }
            print("File is paused: \(pausedFile)")
            
            file.closeFile()
        }else{
            print("Couldn't find file")
            return
        }
    }
    // end of init()
    
    
    public func readChannel(chan: Int) -> [Int16] { // update so that we overload the string vs int call methods, which then pass the correct chan number to a second function that does the actual read.
        
        var data = [Int16]()
        print("--------Reading data--------")
        if endOfHeader <= 0 {
            print("Couldn't find start byte of the actual data, not loading")
            return [-1]
        }
        if let file: FileHandle = FileHandle(forReadingAtPath: self.fileName){
            file.seek(toFileOffset: endOfHeader)
            
            if pausedFile {
                // Currently, we're just concatenating all data cells. Don't like this. Change the return setup, or make which data segment to read a required second argument for paused files
                
                // line 763 in openNSx.m
                for idx in 0..<dataStartByte.count {
                    file.seek(toFileOffset: dataStartByte[idx])
                    //let totalToRead = channelCount * Int(dataPoints[idx]) * 2
                    let dpointsPerRead = Int(Fs) * 60
                    var readSize = channelCount * 2 * dpointsPerRead
                    var buf: Data
                    print("Current file position: \(file.offsetInFile)")
                    while file.offsetInFile < dataEndByte[idx] {
                        if dataEndByte[idx] - file.offsetInFile < readSize {
                            readSize = Int(dataEndByte[idx]) - Int(file.offsetInFile)
                        }
                        buf = file.readData(ofLength: readSize)
                        for b in stride(from: (chan*2)-1, to: buf.count, by: 2*channelCount) {
                            data.append(Int16(littleEndian: buf[b...b+1].withUnsafeBytes({$0.pointee})))
                        }
                        /* // alternative:
                        for b in stride(from: 0, to: buf.count, by: channelCount * 2) {
                            let subset = Array(buf[b..<b+(channelCount*2)])
                            for s in stride(from: 0, to: subset.count, by: 2) {
                                data.append(UnsafePointer(Array(subset[s...s+1])).withMemoryRebound(to: Int16.self, capacity: 1) {
                                    $0.pointee
                                })
                            }
                        }
                        */
                        print("...read \(buf.count) bytes, now at \(file.offsetInFile) in file (of \(endOfFile))")
                    }
                    print("--Finished reading data segment \(idx)--")
                }
                file.closeFile()
                print("--------Finished reading; file closed--------")
                return data
            }else{
                file.seek(toFileOffset: dataStartByte[0])
                // line 782 in openNSx.m here (pretty sure we can skip line 780, because this version will always load all channels)
                print("Yet to code the version for non-paused files")
                file.closeFile()
                return [0, 0, 0, 0, 0] // we're yet to code this one
            }
        }else{
            print("Couldn't open file")
            return [-1]
        }
    }
    
    // overloaded method for reading from an electrode name below
    open func getChannel(chan: Int) -> [Int16] {
        // will need to stride chanCount in this.
        let temp: [Int16] = [0, 0, 0, 0]
        return temp
    }
    // overload of the above for when user supplies electrode name such as "uHCH5"
    open func getChannel(chan: String) -> [Int16] {
        // will need to stride chanCount in this.
        let temp: [Int16] = [0, 0, 0, 0]
        return temp
    }
}
// end of class def
