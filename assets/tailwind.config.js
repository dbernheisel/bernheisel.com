const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  content: [
    "../lib/bern_web/**/*.*ex",
    "./js/**/*.js"
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Inter var"', 'Inter', ...defaultTheme.fontFamily.sans],
        mono: ['"Fira Code VF"', '"Fira Code"', ...defaultTheme.fontFamily.mono]
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
            '--tw-prose-body': theme('colors.black'),
            '--tw-prose-headings': theme('colors.black')
          }
        },
        invert: {
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
            'pre code::before': {content: ''},
            'pre code::after': {content: ''},
            '--tw-prose-body': theme('colors.gray.300'),
            '--tw-prose-headings': theme('colors.gray.300'),
            '--tw-prose-quotes': theme('colors.gray.400'),
            '--tw-prose-captions': theme('colors.gray.500'),
            '--tw-prose-thead': theme('colors.gray.300')
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
