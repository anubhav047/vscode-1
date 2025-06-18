# VS Code with Wingman AI - Demo Script

This document provides a demonstration script for showcasing the integrated VS Code with Wingman AI.

## Pre-Demo Setup

1. **Build the Custom VS Code**:
   ```bash
   ./build-wingman-vscode.sh -p darwin -a x64  # For macOS
   # or
   ./build-wingman-vscode.bat                   # For Windows
   ```

2. **Prepare Demo Environment**:
   - Clean desktop/workspace
   - Close other applications
   - Have a sample project ready (e.g., simple Node.js app)

## Demo Script (1-2 minutes)

### Opening (10 seconds)

> "Today I'll show you a custom build of Visual Studio Code with Wingman AI integrated as a native feature - not as an external extension."

**Action**: Open the custom VS Code build
- Show the clean startup
- Point out Wingman AI icon in the sidebar (naturally integrated)

### Core Integration Demo (30 seconds)

> "Notice that Wingman AI appears as a native VS Code feature in the sidebar. Let me show you that it's completely integrated."

**Action**: Open Extensions panel
- Navigate to Extensions (Ctrl/Cmd+Shift+X)
- Show that Wingman AI is NOT listed in installed extensions
- Search for "wingman" - show it doesn't appear
- Search for "@builtin" - show it's hidden from builtin list too

> "As you can see, Wingman AI is completely hidden from the Extensions marketplace and management - it's truly integrated as a native feature."

### Functionality Demo (30 seconds)

> "But of course, all the Wingman AI functionality is fully available."

**Action**: Demonstrate Wingman AI features
- Open a code file (JavaScript/Python/etc.)
- Click on Wingman AI in sidebar - show the chat interface
- Use keyboard shortcut Ctrl+I (Cmd+I on Mac) to open composer
- Show quick code completion with Ctrl+Shift+Space

**Code example**: Ask Wingman AI to:
- "Create a simple Express server"
- Show the AI response and code generation

### Configuration Demo (20 seconds)

> "The AI provider configuration is seamlessly integrated into VS Code settings."

**Action**: Show configuration
- Open Wingman AI settings panel
- Show AI provider options (OpenAI, Anthropic, Azure, Ollama)
- Demonstrate that settings persist like any other VS Code setting

### Portable Benefits (20 seconds)

> "Since this is a portable build, everything is self-contained."

**Action**: Show portable nature
- Navigate to the data folder
- Show that all settings, extensions, and user data are stored locally
- Explain that this can be moved to any machine without installation

### Closing (10 seconds)

> "This demonstrates a fully integrated AI coding assistant that works as if it were built into VS Code from the ground up, with no external dependencies or extension management needed."

**Action**: Show the build information
- Help > About
- Show custom version number with Wingman integration

## Key Points to Emphasize

1. **Seamless Integration**: Wingman AI loads automatically on first launch
2. **Hidden from Extensions**: Cannot be removed or disabled through normal UI
3. **Full Functionality**: All standard VS Code features remain unchanged
4. **Portable**: Self-contained with no installation required
5. **Professional**: Appears as a native feature, not a hack

## Technical Details (if asked)

### Integration Points:
- **Extension Scanner**: Modified to recognize `builtin: true` flag
- **Extensions View**: Hidden from marketplace and builtin lists
- **Package Configuration**: Publisher changed to `vscode-builtin`

### Build Process:
- Automated build scripts for Windows, macOS, and Linux
- Self-extracting executables for Windows
- DMG installers for macOS
- Portable archives for Linux

### Upgrade Path:
- Documented process for tracking upstream changes
- Minimal modifications to ease future merges
- Automated testing checklist

## Demo Variations

### For Developers:
- Show the source code modifications
- Explain the build process
- Demonstrate the upgrade methodology

### For End Users:
- Focus on functionality and ease of use
- Emphasize the "just works" nature
- Show practical coding scenarios

### For Decision Makers:
- Highlight cost savings (no licensing/subscription for the integration)
- Demonstrate professional appearance
- Show deployment simplicity

## Common Questions & Answers

**Q: "Can users still install other extensions?"**
A: Yes, all normal extension functionality works perfectly. Only Wingman AI is treated specially.

**Q: "What happens when VS Code updates?"**
A: We have a documented upgrade process that tracks upstream changes and maintains the integration.

**Q: "Does this break VS Code's update mechanism?"**
A: This is a completely separate build, so it doesn't interfere with official VS Code installations.

**Q: "Can the AI providers be changed?"**
A: Yes, Wingman AI supports OpenAI, Anthropic Claude, Azure OpenAI, and local Ollama models.

**Q: "Is this legal/compliant?"**
A: Yes, both VS Code and Wingman AI are open-source MIT licensed projects.

## Recording Tips

- Use 1080p or higher resolution
- Enable clear audio recording
- Keep demo under 2 minutes for maximum impact
- Have a backup plan if network/AI services are slow
- Practice the demo several times before recording

## Demo Files

Create these sample files for the demo:

**package.json**:
```json
{
  "name": "demo-project",
  "version": "1.0.0",
  "description": "Demo project for Wingman AI integration",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  }
}
```

**index.js** (empty or with basic content):
```javascript
// Demo file for Wingman AI
console.log("Hello, World!");
```

This provides a clean slate for demonstrating AI code generation capabilities.
