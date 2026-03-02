## Mobile Development Discipline

### Platform Awareness
- Before modifying, confirm whether the code is iOS only / Android only / cross-platform shared
- Check minimum version support for platform-specific API calls
- Permission requests (camera, location, notifications, etc.) must have corresponding usage descriptions

### Performance & UX
- UI operations must be on the main thread; long-running operations must be on background threads
- For list rendering, use proper reuse mechanisms (UITableView reuse / RecyclerView / ListView.builder)
- Memory-sensitive — image loading must consider caching and scaling strategy

### Prohibited
- No hardcoded strings — use localization mechanisms
- No ignoring app lifecycle — handle resource release and restoration during background/foreground transitions
- No modifying Info.plist / AndroidManifest.xml without confirmation
