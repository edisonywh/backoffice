const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  purge: {
    enabled: true,
    content: [
      '../lib/backoffice/components/*.ex',
      '../lib/backoffice/widgets/*.ex',
      '../lib/backoffice/templates/**/*.eex',
      '../lib/backoffice/templates/**/*.leex',
      '../lib/backoffice/views/*.ex',
      '../lib/backoffice/*.ex',
      '../lib/backoffice/live/*.ex',
      '../lib/backoffice/live/*.leex',
      '../lib/backoffice/templates/resource/*.leex'
    ],
    layers: ['components', 'utilities'],
    options: {
      safelist: ['ml-0', 'ml-2', 'ml-4', 'ml-6', 'ml-8'],
    }
  },
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  variants: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
  ],
}
