// MathJax configuration for the math notes
// This configuration is used to load MathJax and set up the necessary macros and options

fetch('./MathJaxMacros.json')
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
                        console.log('MathJax is ready!');
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
        });