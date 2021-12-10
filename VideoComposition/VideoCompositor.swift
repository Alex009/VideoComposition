//
// Created by Aleksey Mikhailov on 10.12.2021.
//

import Foundation
import CoreGraphics
import AVFoundation

enum InputAsset {
  case imageFile(url: URL)
  case videoFile(url: URL)
  case image(image: CGImage)
  case asset(asset: AVAsset)
  case merge(assets: [InputAsset])
  case concat(assets: [InputAsset])
}

struct ExportData {
  let composition: AVComposition
  let videoComposition: AVVideoComposition?
  let audioMix: AVAudioMix?
}

class VideoCompositor {
  enum Errors: Error {
    case createExportSessionFailed
    case exportSessionFailed(cause: Error?)
    case exportCanceled
    case exportIllegalStatus(status: AVAssetExportSession.Status)
  }

  func compose(input: InputAsset, exportUrl: URL) async throws {
    let data: ExportData = try createAsset(input: input)

    guard let exportSession = AVAssetExportSession(
        asset: data.composition,
        presetName: AVAssetExportPresetPassthrough
    ) else {
      throw Errors.createExportSessionFailed
    }

    exportSession.outputURL = exportUrl
    exportSession.outputFileType = .mov
    exportSession.videoComposition = data.videoComposition
    exportSession.audioMix = data.audioMix

    await exportSession.export()

    switch(exportSession.status) {
    case .completed:
      return // success!
    case .failed:
      throw Errors.exportSessionFailed(cause: exportSession.error)
    case .cancelled:
      throw Errors.exportCanceled
    default:
      throw Errors.exportIllegalStatus(status: exportSession.status)
    }
  }

  private func createAsset(input: InputAsset) throws -> ExportData {
    switch (input) {
    case .imageFile(url: let url):
      return try createUrlAsset(url: url)
    case .videoFile(url: let url):
      return try createUrlAsset(url: url)
    case .image(image: let image):
      fatalError()
    case .asset(asset: let asset):
      return try createComposition(asset: asset)
    case .merge(assets: let assets):
      return try createMergeAsset(inputs: mapAssets(inputs: assets))
    case .concat(assets: let assets):
      return try createConcatAsset(assets: mapAssets(inputs: assets))
    }
  }

  private func createUrlAsset(url: URL) throws -> ExportData {
    let asset = AVAsset(url: url)
    return try createComposition(asset: asset)
  }

  private func createComposition(
      asset: AVAsset
  ) throws -> ExportData {
    let composition = AVMutableComposition()

    for track in asset.tracks {
      let compositionTrack = composition.addMutableTrack(
          withMediaType: track.mediaType,
          preferredTrackID: kCMPersistentTrackID_Invalid
      )

      print("add track \(compositionTrack)")
    }

    if !asset.tracks.isEmpty {
      try composition.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: asset, at: .zero)
    }

    return ExportData(
        composition: composition,
        videoComposition: nil,
        audioMix: nil
    )
  }

  private func mapAssets(inputs: [InputAsset]) throws -> [ExportData] {
    try inputs.map {
      try createAsset(input: $0)
    }
  }

  private func createMergeAsset(inputs: [ExportData]) throws -> ExportData {
    let composition = AVMutableComposition()

    var videoInstructions = [AVVideoCompositionInstruction]()

    let backgroundInstruction = AVMutableVideoCompositionInstruction()
    backgroundInstruction.backgroundColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.5)

    videoInstructions.append(backgroundInstruction)

    for input in inputs {
      let asset: AVAsset = input.composition

      for track in asset.tracks {
        let compositionTrack = composition.addMutableTrack(
            withMediaType: track.mediaType,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        print("add track \(compositionTrack)")

        if track.mediaType == .video {
          let videoLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)

          let videoInstruction = AVMutableVideoCompositionInstruction()
          videoInstruction.layerInstructions = [videoLayer]
          videoInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: track.timeRange.duration)

          print("add video instruction \(videoInstruction)")
          videoInstructions.append(videoInstruction)
        }
      }

      if !asset.tracks.isEmpty {
        try composition.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: asset, at: .zero)
      }
    }

    backgroundInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)

    let videoComposition = AVMutableVideoComposition()
    videoComposition.instructions = videoInstructions
    videoComposition.renderSize = CGSize(width: 360, height: 720)
    videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)

    return ExportData(
        composition: composition,
        videoComposition: videoComposition,
        audioMix: nil
    )
  }

  private func createConcatAsset(assets: [ExportData]) -> ExportData {
    fatalError()
  }
}
