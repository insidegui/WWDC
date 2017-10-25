//
//  PhotosJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum PhotoKeys: String, JSONSubscriptType {
    case id, ratio

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class PhotosJSONAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = Photo

    func adapt(_ input: JSON) -> Result<Photo, AdapterError> {
        guard let id = input[PhotoKeys.id].string else {
            return .error(.missingKey(PhotoKeys.id))
        }

        guard let ratio = input[PhotoKeys.ratio].double else {
            return .error(.missingKey(PhotoKeys.ratio))
        }

        let representations = PhotoRepresentationSize.all.map { size -> PhotoRepresentation in
            let rep = PhotoRepresentation()

            rep.remotePath = "\(id)/\(size.rawValue).jpeg"
            rep.width = size.rawValue

            return rep
        }

        let photo = Photo()

        photo.identifier = id
        photo.aspectRatio = ratio
        photo.representations.append(objectsIn: representations)

        return .success(photo)
    }

}
