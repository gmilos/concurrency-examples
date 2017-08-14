typealias Request = ()
typealias Response = ()

enum ServiceError : Error {
    case noDowntstreamService
    case allDowntstreamServicesFailed
}




