const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  purge: [
    "../lib/bern_web/live/**/*.ex",
    "../lib/bern_web/live/**/*.leex",
    "../lib/bern_web/templates/**/*.eex",
    "../lib/bern_web/templates/**/*.leex",
    "../lib/bern_web/views/**/*.ex",
    "../lib/bern_web/components/**/*.ex",
    "./js/**/*.js"
  ],
  theme: {
    typography: (theme) => ({
      default: {
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
      dark: {
        css: {
          'blockquote': {
            color: theme('colors.gray.500'),
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
    screens: {
      sm: "640px",
      md: "768px",
      lg: "1024px",
      "dark": {"raw": "(prefers-color-scheme: dark)"}
    },
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
      }
    },
  },
  variants: {},
  plugins: [
    require('@tailwindcss/ui'),
    require('@tailwindcss/typography')
  ],
};
