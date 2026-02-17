/** @type {import('tailwindcss').Config} */
module.exports = {
  presets: [require('nativewind/preset')],
  content: ['./app/**/*.{js,jsx}', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          neon: '#32f5ff',
          amber: '#ffae35',
          mint: '#96f7d2'
        },
        surface: {
          dark: '#050608',
          light: '#f7f3eb'
        }
      },
      fontFamily: {
        display: ['SpaceGrotesk', 'System'],
        body: ['Inter', 'System']
      }
    }
  },
  plugins: []
};
