const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  purge: [
    '../lib/backoffice/components/*.ex',
    '../lib/backoffice/templates/**/*.eex',
    '../lib/backoffice/templates/**/*.leex',
    '../lib/backoffice/views/*.ex',
    '../lib/backoffice/*.ex',
    '../lib/backoffice/live/*.ex',
    '../lib/backoffice/live/*.leex',
    '../lib/backoffice/templates/resource/*.leex'
  ],
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
