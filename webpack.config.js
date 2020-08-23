const path = require('path');
const webpack = require('webpack');

module.exports = {
    entry: './src/index.tsx',
    output: {
        filename: 'index.js',
        path: path.resolve(__dirname, 'public'),
    },

    resolve: {
        extensions: ['.ts', '.tsx', '.js', '.jsx']
    },

    module: {
        rules: [
            {
              test: /\.(png|svg|jpg|gif)$/,
              exclude: /node_modules/,
              use: [
               'file-loader',
              ],
            },
            {
                test: /\.ts(x?)$/,
                exclude: /node_modules/,
                use: [
                    {
                        loader: "ts-loader"
                    },
                ]
            },
            {
              test: /\.css$/i,
              exclude: /node_modules/,
              use: ['style-loader', 'css-loader'],
            },
            {
                enforce: "pre",
                exclude: /node_modules/,
                test: /\.js$/,
                loader: "source-map-loader"
            },
            {
              test: /\.s[ac]ss$/i,
              exclude: /node_modules/,
              use: [
                'style-loader',
                'css-loader',
                'sass-loader',
              ],
            },
        ]
    },

    plugins: [],

    externals: {
        "react": "React",
        "react-dom": "ReactDOM"
    }
};
