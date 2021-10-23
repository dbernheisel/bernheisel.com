const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  mode: 'jit',
  purge: [
    "../lib/bern_web/live/**/*.ex",
    "../lib/bern_web/live/**/*.heex",
    "../lib/bern_web/templates/**/*.eex",
    "../lib/bern_web/templates/**/*.heex",
    "../lib/bern_web/views/**/*.ex",
    "../lib/bern_web/components/**/*.ex",
    "./js/**/*.js"
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', 'Inter', ...defaultTheme.fontFamily.sans],
        mono: ['Fira Code VF', 'Fira Code', ...defaultTheme.fontFamily.mono]
      },
      colors: {
        brand: {
          '50': '#fff8f1',
          '100': '#feecdc',
          '200': '#fcd9bd',
          '300': '#fdba8c',
          '400': '#ff8a4c',
          '500': '#ff5a1f',
          '600': '#d03801',
          '700': '#b43403',
          '800': '#8a2c0d',
          '900': '#771d1d'
        },
        accent: {
          '50': '#edfafa',
          '100': '#d5f5f6',
          '200': '#afecef',
          '300': '#7edce2',
          '400': '#16bdca',
          '500': '#0694a2',
          '600': '#047481',
          '700': '#036672',
          '800': '#05505c',
          '900': '#014451'
        },
      },
      screens: {
        'print': {'raw': 'print'}
      },
      typography: (theme) => ({
        DEFAULT: {
          css: {
            'a': {
              color: theme('colors.brand.700'),
              textDecoration: 'none',
              transition: "colors",
              transitionDuration: "150ms",
              transitionProperty: "border-color, color",
              transitionTimingFunction: "cubic-bezier(0.4, 0, 0.2, 1)",
              borderBottomColor: theme('colors.accent.500'),
              borderBottomWidth: 1,
              "&:hover": {
                color: theme('colors.brand.500'),
                borderBottomColor: theme('colors.accent.400'),
              }
            },
            'blockquote': {
              borderLeftColor: theme('colors.purple.500'),
            },
            'blockquote p:first-of-type::before': null,
            'blockquote p:last-of-type::after': null,
            'code': {
              color: null,
              fontWeight: null,
            },
            'code::before': {content: null},
            'code::after': {content: null},
            'pre': {
              color: null,
              backgroundColor: null,
            },
            'pre code': {
              backgroundColor: null,
              color: null,
              fontSize: null,
              fontFamily: null,
              lineHeight: null,
            },
            'pre code::before': {content: ''},
            'pre code::after': {content: ''},
          },
        },
        print: {
          css: {
            color: theme('colors.black'),
            h1: { color: theme('colors.black') },
            h2: { color: theme('colors.black') },
            h3: { color: theme('colors.black') },
            h4: { color: theme('colors.black') },
            h5: { color: theme('colors.black') },
            h6: { color: theme('colors.black') }
          }
        },
        dark: {
          css: {
            'blockquote': {
              color: theme('colors.gray.400'),
            },
            'pre': {
              backgroundColor: '#272822',
            },
            'pre code': {
              backgroundColor: null,
              color: null,
              fontSize: null,
              fontFamily: null,
              lineHeight: null,
            },
            color: theme('colors.gray.300'),
            h1: {
              color: theme('colors.gray.300'),
            },
            h2: {
              color: theme('colors.gray.300'),
            },
            h3: {
              color: theme('colors.gray.300'),
            },
            h4: {
              color: theme('colors.gray.300'),
            },
            h5: {
              color: theme('colors.gray.300'),
            },
            h6: {
              color: theme('colors.gray.300'),
            },
            figcaption: {
              color: theme('colors.gray.500'),
            },
            'thead': {
              color: theme('colors.gray.300')
            }
          }
        },
      }),
    },
  },
  variants: {
    extend: {
      borderWidth: ['responsive', 'last'],
      typography: ['dark']
    }
  },
  plugins: [
    require('@tailwindcss/typography')
  ],
};
