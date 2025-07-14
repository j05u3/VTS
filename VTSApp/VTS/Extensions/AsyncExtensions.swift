import Foundation

extension AsyncThrowingStream {
    public static func makeStream(of elementType: Element.Type = Element.self) -> (stream: AsyncThrowingStream<Element, Error>, continuation: AsyncThrowingStream<Element, Error>.Continuation) {
        var continuation: AsyncThrowingStream<Element, Error>.Continuation!
        let stream = AsyncThrowingStream<Element, Error> { cont in
            continuation = cont
        }
        return (stream, continuation)
    }
}