#!/bin/bash

git checkout gh-pages
git rm -rf .
cp -r book/* .
touch .nojekyll
git add .
git commit -m "Deploy site"
git push origin gh-pages