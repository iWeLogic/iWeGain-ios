/// Expected failures of data sources, thrown with typed throws (`throws(DataError)`).
nonisolated enum DataError: Error, Equatable {
    case network(Network)
    case local(Local)

    enum Network: Equatable {
        case noInternet, unauthorized, forbidden, notFound, serverError
        /// The task was cancelled; never shown to the user.
        case cancelled
        case unknown
    }

    enum Local: Equatable {
        case diskFull, notFound, unknown
    }
}
