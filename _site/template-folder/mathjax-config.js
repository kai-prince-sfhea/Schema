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
                loader: {load: ['[tex]/texhtml','[tex]/html']},
                tex:
                {
                    allowTexHTML: true,
                    packages: {'[+]': ['texhtml','html']},
                    macros: macros
                }
            };

            (function () {
            var script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/mathjax@4/tex-mml-chtml.js';
            script.async = true;
            document.head.appendChild(script);
            })();
        });