//  Tollservice.swift
//  toll-app
//
//  Created by Carolina Mera  on 11/09/2025.
//API Service to fetch toll data

import Foundation

enum GHError: Error {
    case invalidURL
    case invalidResponse
    case invalidData
}


struct TollService {
    static let shared = TollService()
    
    func getTolls() async throws -> [Vegobjekt] {
        let endpoint = "https://nvdbapiles.atlas.vegvesen.no/vegobjekter/api/v4/vegobjekter/45?inkluder=lokasjon&inkluder=egenskaper&inkluderAntall=false"
        
        guard let url = URL(string: endpoint) else {
            throw GHError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("toll-app (carolina.m@gmail.com)", forHTTPHeaderField: "X-Client")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw GHError.invalidResponse
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let response = try decoder.decode(VegobjektResponse.self, from: data)
            #if DEBUG
            print("API object count: \(response.objekter.count)")
            #endif
            
            let vegobjekter: [Vegobjekt] = response.objekter.map { api in
                let egenskaper = api.egenskaper.map { e in
                    Egenskap(id: e.id, navn: e.navn, verdi: e.verdi)
                }
                
                let lokasjon: Lokasjon? = {
                    guard let l = api.lokasjon else { return nil }
                    let geo = Geometri(wkt: l.geometri.wkt, srid: l.geometri.srid)
                    return Lokasjon(geometri: geo)
                }()
                return Vegobjekt(id: api.id, href: api.href, egenskaper: egenskaper, lokasjon: lokasjon)
            }
            return vegobjekter
        } catch {
            #if DEBUG
            print("Decoding error: ", error)
            #endif
            throw GHError.invalidData
        }
    }
}
