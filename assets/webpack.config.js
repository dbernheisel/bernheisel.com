const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = (_env, options) => {
  const devMode = options.mode !== 'production';

  return {
    optimization: {
      minimizer: [
        '...',
        new CssMinimizerPlugin()
      ]
    },
    entry: {
      app: ["./js/app.js", "./css/app.css"],
      vendor: ["./js/vendor.js"]
    },
    output: {
      filename: '[name].js',
      path: path.resolve(__dirname, '../priv/static/js'),
      publicPath: '/js/'
    },
    devtool: 'source-map',
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        },
        {
          test: /\.[s]?css$/,
          use: [
            MiniCssExtractPlugin.loader,
            { loader: "css-loader", options: {
                sourceMap: true,
                importLoaders: 1 ,
                url: (url, _resourcePath) => {
                  // Don't handle absolute urls
                  if (url.startsWith('/')) {
                    return false;
                  }

                  return true;
                }
              }
            },
            { loader: "postcss-loader", options: { sourceMap: true } },
          ],
        },
        {
          test: /\.(woff(2)?|ttf|eot|svg)(\?v=\d+\.\d+\.\d+)?$/,
          use: [
            {
              loader: "file-loader",
              options: {
                name: "[name].[ext]",
                outputPath: "../fonts"
              }
            }
          ]
        }
      ]
    },
    plugins: [
      new MiniCssExtractPlugin({ filename: '../css/app.css' }),
      new CopyWebpackPlugin({ patterns: [{ from: 'static/', to: '../' }] })
    ]
  }
};
