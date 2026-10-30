enum Queries {
  static let departureCount = 100
  static let nearestCount = 20
  static let blurSlack = 150

  static let departures = """
    query Departures($ids: [String]!, $count: Int!) {
      stopPlaces(ids: $ids) {
        id
        estimatedCalls(numberOfDepartures: $count, numberOfDeparturesPerLineAndDestinationDisplay: \(Favorite.shownRange.upperBound), timeRange: 14400, arrivalDeparture: departures, includeCancelledTrips: true) {
          aimedDepartureTime
          expectedDepartureTime
          realtime
          cancellation
          destinationDisplay { frontText }
          quay { id publicCode }
          serviceJourney { id line { id publicCode transportMode presentation { colour textColour } } }
          situations { id summary { value language } }
        }
      }
    }
    """

  static let nearest = """
    query Nearest($lat: Float!, $lon: Float!, $max: Float!, $first: Int!) {
      nearest(latitude: $lat, longitude: $lon, maximumDistance: $max, filterByPlaceTypes: [stopPlace], multiModalMode: parent, first: $first) {
        edges { node { place { ... on StopPlace { id name latitude longitude transportMode } } } }
      }
    }
    """

  static let platforms = """
    query Platforms($id: String!) {
      stopPlace(id: $id) {
        quays(filterByInUse: true) {
          id
          publicCode
          lines { id publicCode transportMode presentation { colour textColour } }
          estimatedCalls(numberOfDepartures: 20, timeRange: 86400) { destinationDisplay { frontText } }
        }
      }
    }
    """
}
