//
//  CameraSession+Focus.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension CameraSession {
  /**
   Focuses the Camera to the specified point. The point must be in the Camera coordinate system, so {0...1} on both axis.
   */
  func focus(point: CGPoint) throws {
    guard let device = videoDeviceInput?.device else {
      throw CameraError.session(SessionError.cameraNotReady)
    }
    if !device.isFocusPointOfInterestSupported {
      throw CameraError.device(DeviceError.focusNotSupported)
    }

    VisionLogger.log(level: .info, message: "Focusing (\(point.x), \(point.y))...")

    do {
      try device.lockForConfiguration()
      defer {
        device.unlockForConfiguration()
      }

      // Set Focus
      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = point
      }

      if device.isLockingFocusWithCustomLensPositionSupported {
        device.setFocusModeLocked(lensPosition: 1) { [weak self] _ in
          guard let self = self else { return }
          guard (try? device.lockForConfiguration()) != nil else { return }
          defer {
            device.unlockForConfiguration()
          }

          if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
          }

          if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .far
          }
        }
      }

      // Remove any existing listeners
      NotificationCenter.default.removeObserver(self,
                                                name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                                object: nil)

      // Listen for focus completion
      device.isSubjectAreaChangeMonitoringEnabled = true
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(subjectAreaDidChange),
                                             name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                             object: nil)
    } catch {
      throw CameraError.device(DeviceError.configureError)
    }
  }

  @objc
  func subjectAreaDidChange(notification _: NSNotification) {
    guard let device = videoDeviceInput?.device else {
      return
    }

    try? device.lockForConfiguration()
    defer {
      device.unlockForConfiguration()
    }

    // Reset Focus to continuous/auto
    if device.isFocusPointOfInterestSupported {
      device.focusMode = .continuousAutoFocus
    }

    // Disable listeners
    device.isSubjectAreaChangeMonitoringEnabled = false
    // Remove any existing listeners
    NotificationCenter.default.removeObserver(self,
                                              name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                              object: nil)
  }
}
