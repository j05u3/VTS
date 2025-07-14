Help me write a build/spec plan for a speech to text macos app that mainly:

* Allows the user to set their own API keys, supporting Groq API Key and OpenAI API Key and lets the user choose the model, allowing the user to customize some things like the system prompt (to help better recognize the context/terms of the transcriptions)
* Allows the user to choose the mic device (ideally have a priority list for them)
* Allows to configure a global keyboard shortcut to toggle recording on/off (by default it's command + shift + semicolon)
* Ideally replaces the native macos dictation tool and behaves similarly

Use a modern stack ideally but also keep it as simple as possible. I plan on releasing the code as open source in Github with MIT license.