// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Vapor


func docRoutes(_ app: Application) throws {
    // Underspecified documentation routes - these routes lack the reference, the archive, or both.
    // Therefore, these parts need to be queried from the database and the request will be
    // redirected to the fully formed documentation URL.
    app.get(":owner", ":repository", "documentation") { req -> Response in
        throw Abort.redirect(to: try await req.getDocRedirect(), fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "documentation", "**") { req -> Response in
        throw Abort.redirect(to: try await req.getDocRedirect(), fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "tutorials", "**") { req -> Response in
        throw Abort.redirect(to: try await req.getDocRedirect(), fragment: .tutorials)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation") { req -> Response in
        throw Abort.redirect(to: try await req.getDocRedirect(), fragment: .documentation)
    }.excludeFromOpenAPI()

    // Stable URLs with reference (real reference or ~)
    app.get(":owner", ":repository", ":reference", "documentation", ":archive") {
        let route = try await $0.getDocRoute(fragment: .documentation)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation", ":archive", "**") {
        let route = try await $0.getDocRoute(fragment: .documentation)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconIco)) {
        let route = try await $0.getDocRoute(fragment: .faviconIco)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconSvg)) {
        let route = try await $0.getDocRoute(fragment: .faviconSvg)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "css", "**") {
        let route = try await $0.getDocRoute(fragment: .css)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "data", "**") {
        let route = try await $0.getDocRoute(fragment: .data)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "images", "**") {
        let route = try await $0.getDocRoute(fragment: .images)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "img", "**") {
        let route = try await $0.getDocRoute(fragment: .img)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "index", "**") {
        let route = try await $0.getDocRoute(fragment: .index)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "js", "**") {
        let route = try await $0.getDocRoute(fragment: .js)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.linkablePaths)) {
        let route = try await $0.getDocRoute(fragment: .linkablePaths)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) {
        let route = try await $0.getDocRoute(fragment: .themeSettings)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "tutorials", "**") {
        let route = try await $0.getDocRoute(fragment: .tutorials)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
}


private extension PathComponent {
    static func fragment(_ fragment: DocRoute.Fragment) -> Self { "\(fragment)" }
}


#warning("move this or make it private")
extension Parameters {
    func pathElements(for fragment: DocRoute.Fragment, archive: String? = nil) -> [String] {
        let catchall = {
            var p = self
            return p.getCatchall()
        }()
        switch fragment {
            case .data, .documentation, .tutorials:
                // DocC lowercases "target" names in URLs. Since these routes can also
                // appear in user generated content which might use uppercase spelling, we need
                // to lowercase the input in certain cases.
                // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
                // and https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2172
                // for details.
                return ([archive].compacted() + catchall).map { $0.lowercased() }
            case .css, .faviconIco, .faviconSvg, .images, .img, .index, .js, .linkablePaths, .themeSettings:
                return catchall
        }
    }
}
 
#warning("move this or make it private")
struct DocRedirect {
    var owner: String
    var repository: String
    var target: DocumentationTarget
    var path: String
}

extension Request {
    func getDocRedirect() async throws -> DocRedirect {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }

        let anchor = url.fragment.map { "#\($0)"} ?? ""
        let path = parameters.getCatchall().joined(separator: "/").lowercased() + anchor

        let target: DocumentationTarget?
        switch parameters.get("reference") {
            case let .some(ref):
                if ref == .current {
                    target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
                } else {
                    target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository, reference: .init(ref))
                }
                
            case .none:
                target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
        }
        guard let target else { throw Abort(.notFound) }

        return .init(owner: owner, repository: repository, target: target, path: path)
    }
    
    func getDocRoute(fragment: DocRoute.Fragment) async throws -> DocRoute {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }
        let archive = parameters.get("archive")

        if parameters.get("reference") == String.current {
            guard let params = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)?.internal
            else { throw Abort(.notFound) }
            if fragment.requiresArchive {
                guard let archive else { throw Abort(.badRequest) }
                guard archive.lowercased() == params.archive.lowercased() else { throw Abort(.notFound) }
            }
            let pathElements = parameters.pathElements(for: fragment, archive: archive)
            return DocRoute(owner: owner, repository: repository, docVersion: .current(referencing: params.reference), fragment: fragment, pathElements: pathElements)
        } else {
            guard let ref = parameters.get("reference") else { throw Abort(.badRequest) }
            if fragment.requiresArchive && archive == nil { throw Abort(.badRequest) }
            let pathElements = parameters.pathElements(for: fragment, archive: archive)
            return DocRoute(owner: owner, repository: repository, docVersion: .reference(ref), fragment: fragment, pathElements: pathElements)
        }
    }
    
    var referenceIsCurrent: Bool {
        parameters.get("reference") == String.current
    }
}


private extension Abort {
    static func redirect(to redirect: DocRedirect, fragment: DocRoute.Fragment) -> Abort {
        .redirect(to: SiteURL.relativeURL(owner: redirect.owner,
                                                     repository: redirect.repository,
                                                     documentation: redirect.target,
                                                     fragment: fragment,
                                                     path: redirect.path))
    }
}
