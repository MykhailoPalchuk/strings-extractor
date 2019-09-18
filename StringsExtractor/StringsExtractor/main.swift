//
//  main.swift
//  StringsExtractor
//
//  Created by Mykhailo Palchuk on 9/16/19.
//  Copyright © 2019 mpalchuk. All rights reserved.
//

import Foundation

struct FileStrings {
  let fileName: String
  let strings: [String]
}

let lineRegex = try! NSRegularExpression(pattern: "^.*\".*\".*", options: .anchorsMatchLines)
let wordRegex = try! NSRegularExpression(pattern: "\".*\"")

func main() {

  guard CommandLine.argc > 2 else {
    print("Give me a path")
    return
  }

  serialize(extractStrings(from: CommandLine.arguments[1]), to: CommandLine.arguments[2])
}

func extractStrings(from path: String) -> [FileStrings] {
  var results = [FileStrings]()
  if path.range(of: ".swift")?.upperBound == path.endIndex {
    if let strings = extractStrings(of: path) {
      results.append(strings)
    }
  } else {
    do {
      let contents = try FileManager.default
        .contentsOfDirectory(atPath: path)
        .filter(shouldProcessFile(at:))
      results += contents.flatMap { extractStrings(from: "\(path)/\($0)") }
    } catch {
      print(error.localizedDescription)
    }
  }
  return results
}

func extractStrings(of file: String) -> FileStrings? {
  print("Processing file \(file)")
  let url = URL(fileURLWithPath: file)

  do {
    let stringContent = try String(contentsOf: url, encoding: .utf8)
    let lineMatches: [String] = lineRegex
      .matches(in: stringContent, range: NSRange(location: 0, length: stringContent.count))
      .map { getString(from: $0, string: stringContent) }
      .filter(shouldProcessLine(_:))
    print(lineMatches)
    let wordMatches: [String] = lineMatches
      .flatMap { line in
        wordRegex
          .matches(in: line, range: NSRange(location: 0, length: line.count))
          .map { getString(from: $0, string: line).trimmingCharacters(in: .whitespaces) }
          .filter(shouldIncludeString(_:))
      }
    print("Words: \(wordMatches)")
    if wordMatches.count > 0 {
      let fileName = String(file.split(separator: "/").last!)
      return FileStrings(fileName: fileName, strings: wordMatches)
    } else {
      return nil
    }
  } catch {
    print("Error at extractStrings(of:) \(error.localizedDescription)")
    return nil
  }
}

func shouldProcessFile(at path: String) -> Bool {
  return !path.starts(with: ".") &&
    !path.contains("API") &&
    !path.contains("GMS") &&
    !path.contains("Tests") &&
    !path.contains("Analytics") &&
    !path.contains("AppEnvironment.swift") &&
    path != "Vendor"
}

func shouldProcessLine(_ string: String) -> Bool {
  return !string.contains("#imageLiteral") &&
  !string.contains("#colorLiteral") &&
  !string.contains("init(coder:) has not been implemented") &&
  !string.contains("UIImage(named:") &&
  !string.contains("UIColor(named:")
}

func shouldIncludeString(_ string: String) -> Bool {
  return !string.isEmpty &&
    string != "\"\""
}

func getString(from match: NSTextCheckingResult, string: String) -> String {
  let range = match.range(at: 0)
  let start = string.index(string.startIndex, offsetBy: range.location)
  let end = string.index(string.startIndex, offsetBy: range.location + range.length)
  return String(string[start..<end])
}

func serialize(_ strings: [FileStrings], to path: String) {
  do {
    try strings
      .map { "// \($0.fileName) \n \($0.strings.joined(separator: "\n"))"}
      .joined(separator: "\n\n")
      .write(to: URL(fileURLWithPath: path), atomically: false, encoding: .utf8)
  } catch {
    print("Error serializing results \(error.localizedDescription)")
    exit(EXIT_FAILURE)
  }
}

main()

