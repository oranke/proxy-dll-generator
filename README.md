# proxy-dll-generator
...for very simple API Hooking.

![SShot](sshot-001.png)

This creates a DLL project file for Delphi. It based on the lecture "[Create your Porxy DLLs automatically](http://www.codeproject.com/Articles/16541/Create-your-Proxy-DLLs-automatically )".



It was built using Lazarus and requires "[VirtualTreeview-Lazarus](https://github.com/blikblum/VirtualTreeView-Lazarus)".

I tried to use "[pe-image-for-delphi](https://github.com/vdisasm/pe-image-for-delphi)" to get the DLL information, but Lazarus does not support anonymous functions. So I forked it and made "[pe-image-for-Lazarus](https://github.com/oranke/pe-image-for-Lazarus)".

Have fun.
