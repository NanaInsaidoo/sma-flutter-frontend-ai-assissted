const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const [inputDirectory, filePattern, outputPath] = process.argv.slice(2);
if (!inputDirectory || !filePattern || !outputPath) {
  throw new Error(
    'Usage: node tool/build_contact_sheet.js <directory> <prefix|*substring> <output.png>',
  );
}

const matchesPattern = filePattern.startsWith('*')
  ? (name) => name.includes(filePattern.slice(1))
  : (name) => name.startsWith(filePattern);
const files = fs
  .readdirSync(inputDirectory)
  .filter((name) => matchesPattern(name) && name.endsWith('.png'))
  .sort();
if (files.length === 0) throw new Error(`No screenshots match ${filePattern}`);

const columns = 6;
const cellWidth = 190;
const gap = 8;
const images = files.map((name) => ({
  name,
  image: PNG.sync.read(fs.readFileSync(path.join(inputDirectory, name))),
}));
const cellHeight = Math.round(
  (images[0].image.height / images[0].image.width) * cellWidth,
);
const rows = Math.ceil(images.length / columns);
const sheet = new PNG({
  width: columns * cellWidth + (columns + 1) * gap,
  height: rows * cellHeight + (rows + 1) * gap,
  colorType: 6,
});
sheet.data.fill(242);

for (let index = 0; index < images.length; index += 1) {
  const source = images[index].image;
  const left = gap + (index % columns) * (cellWidth + gap);
  const top = gap + Math.floor(index / columns) * (cellHeight + gap);
  for (let y = 0; y < cellHeight; y += 1) {
    const sourceY = Math.min(
      source.height - 1,
      Math.floor((y / cellHeight) * source.height),
    );
    for (let x = 0; x < cellWidth; x += 1) {
      const sourceX = Math.min(
        source.width - 1,
        Math.floor((x / cellWidth) * source.width),
      );
      const sourceOffset = (sourceY * source.width + sourceX) * 4;
      const targetOffset = ((top + y) * sheet.width + left + x) * 4;
      source.data.copy(sheet.data, targetOffset, sourceOffset, sourceOffset + 4);
    }
  }
}

fs.writeFileSync(outputPath, PNG.sync.write(sheet));
process.stdout.write(`${files.length} screenshots -> ${outputPath}\n`);
