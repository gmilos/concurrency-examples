typealias Request = ()
typealias Response = ()

enum ServiceError : Error {
    case noDownstreamService
    case allDownstreamServicesFailed
}




