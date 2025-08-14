// MathJax configuration for the math notes
// This configuration is used to load MathJax and set up the necessary macros and options

fetch('./Mathjax.json')
    .then(response => response.json())
    .then(jsonArray =>
        {
            const macros = jsonArray;
            console.log(macros);
            window.MathJax =
            {
                startup:
                {
                    ready: () =>
                    {
                        console.log('MathJax is loaded!');
                        MathJax.startup.defaultReady();
                        console.log('MathJax is ready!');
                        MathJax.startup.promise.then(() =>
                        {
                            console.log('MathJax typeset complete!');
                        });
                    }
                },
                menuOptions:
                {
                    annotationTypes:
                    {
                        TeX: ['TeX', 'LaTeX', 'application/x-tex'],
                        ContentMathML: ['MathML-Content', 'application/mathml-content+xml'],
                        OpenMath: ['OpenMath']
                    }
                },
                loader: {load: ['[tex]/texhtml','[tex]/html','ui/safe']},
                tex:
                {
                    allowTexHTML: true,
                    packages: {'[+]': ['texhtml','html']},
                    macros: macros
                },
                options: {
                    safeOptions: {
                        allow: {
                            URLs: 'safe',
                            classes: 'safe',
                            cssIDs: 'safe',
                            styles: 'safe'
                        },
                        safeProtocols: {
                            http: false,
                            https: true,
                            file: true,
                            javascript: false,
                            data: false
                        },
                        safeStyles: {
                            color: true,
                            backgroundColor: true,
                            border: true,
                            cursor: true,
                            margin: true,
                            padding: true,
                            textShadow: true,
                            fontFamily: true,
                            fontSize: true,
                            fontStyle: true,
                            fontWeight: true,
                            opacity: true,
                            outline: true
                        }
                    }
                }
            };

            (function () {
            var script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/mathjax@4/tex-mml-chtml.js';
            script.async = true;
            document.head.appendChild(script);
            })();
        });