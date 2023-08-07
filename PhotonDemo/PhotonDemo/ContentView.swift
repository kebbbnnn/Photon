//
//  ContentView.swift
//  PhotonDemo
//
//  Created by Kevin Ladan on 7/8/23.
//

import SwiftUI
import Photon

struct ContentView: View {
    @State private var stamps: [Stamp] = []
    var body: some View {
        let length = UIScreen.main.bounds.width / 3
        ScrollView {
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3)) {
                ForEach(self.stamps, id: \.self) { stamp in
                    AsyncImage(url: URL(string: stamp.stamp_url)!) { image in
                        image
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: length, height: length)
                    } placeholder: {
                        ProgressView()
                            .frame(width: length, height: length)
                    }
                    .clipped()
                }
            }
            .padding(4)
        }
        .onAppear {
            var count: Int = 0
            let url = URL(string: "https://stampchain.io/stamp.json")!
            Photon.stream(source: .server(url)) { (stamps: Set<Stamp>) in
                count += stamps.count
                print("count: \(count)")
                self.stamps.append(contentsOf: stamps)
            } completionBlock: {
                print("complete!")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
