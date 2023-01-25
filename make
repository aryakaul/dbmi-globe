#!/bin/bash
set -u
set -e

dl_googlesheet() {
    latlongdata="./docs/locations.csv"
    echo "name,lat,lng" > $latlongdata
    curl -L $form_link | sed 1d | awk -F '\t' '{printf "%s,%s\n", $2, $3}' >> $latlongdata
}

build_website() {
    num_responses=$(wc -l $latlongdata | awk '{print $1}')
    echo "
<head>
  <style> body { margin: 0; } </style>
  <script src="//unpkg.com/d3"></script>
  <script src="//unpkg.com/d3-dsv"></script>
  <script src="//unpkg.com/globe.gl"></script>
</head>

<body>
  <div id="globeViz"></div>

  <script>

    const weightColor = d3.scaleSequentialSqrt(d3.interpolateYlOrRd)
        .domain([0, $num_responses]);

    const colorInterpolator = t => \`rgba(255,100,50,\${Math.sqrt(1-t)})\`;

    const dbmi = [{
        lat: 42.3354375,
        lng: -71.1044172,
        repeatPeriod: 700,
        maxR: 3,
        propagationSpeed: -0.5,
        label: 'Baym Lab',
        color: 'salmon',
        radius: 0.3,
        size: 1,
    }];

    const world = Globe()
      (document.getElementById('globeViz'))
      .globeImageUrl('//unpkg.com/three-globe/example/img/earth-blue-marble.jpg')
      .bumpImageUrl('//unpkg.com/three-globe/example/img/earth-topology.png')
      .backgroundImageUrl('//unpkg.com/three-globe/example/img/night-sky.png')
      .ringsData(dbmi)
      .ringMaxRadius('maxR')
      .ringPropagationSpeed('propagationSpeed')
      .ringRepeatPeriod('repeatPeriod')
      .ringColor(() => colorInterpolator)
      .labelsData(dbmi)
      .labelText('label')
      .labelColor('color')
      .labelSize('size')
      .labelDotRadius('radius')
      .hexBinResolution(3)
      .hexTopColor(d => weightColor(d.sumWeight))
      .hexSideColor(d => weightColor(d.sumWeight))
      //.hexBinMerge(true)
      .hexLabel(d => \`
        <ul><li>
         \${d.points.slice().sort((a, b) => b.name - a.name).map(d => d.name).join('</li><li>')}
        </li></ul>
      \`)
      .enablePointerInteraction(true);

    fetch('./locations.csv').then(res => res.text())
      .then(csv => d3.csvParse(csv, ({ name, lat, lng }) => ({ name: name, lat: +lat, lng: +lng })))
      .then(data => world.hexBinPointsData(data));

    // Add auto-rotation
    world.controls().autoRotate = true;
    world.controls().autoRotateSpeed = 0.1;
  </script>
</body>
" > $(pwd)/docs/baym-test/index.html

    git add ./*
    git commit -m "update website"
    git push
}

main() {
    form_link=""
    for i in "$@"; do
    case $i in
        -f|--formlink)
        form_link="$2"
        shift
        shift
        ;;
        *)    
        ;;
    esac
    done
    [ -z "$form_link" ] && die "form link not passed!"
    dl_googlesheet
    build_website
}

die() {
    printf 'error: %s.\n' "$1" >&2
    exit 1
}

main "$@"
