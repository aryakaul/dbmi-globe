#!/bin/bash
set -u
#set -x

dl_googlesheet() {
    form_link="$(<"$form_link_file")"
    latlongdata="./docs/locations.csv"
    echo "name,lat,lng" > $latlongdata
    curl -L $form_link | sed 1d | awk -F '\t' '{printf "%s,%s\n", $2, $3}' | sed 's/, /,/'>> $latlongdata
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
        .domain([1, $num_responses]);

    const colorInterpolator = t => \`rgba(255,100,50,\${Math.sqrt(1-t)})\`;

    const dbmi = [{
        lat: 42.3354375,
        lng: -71.1044172,
        repeatPeriod: 700,
        maxR: 3,
        propagationSpeed: -0.5,
        label: 'DBMI',
        color: 'salmon',
        radius: 0.3,
        size: 1.8,
    }];

    const world = Globe()
      (document.getElementById('globeViz'))
      .globeImageUrl('//unpkg.com/three-globe/example/img/earth-blue-marble.jpg')
      .bumpImageUrl('//unpkg.com/three-globe/example/img/earth-topology.png')
      .backgroundImageUrl('//unpkg.com/three-globe/example/img/night-sky.png')
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
        \${d.points.slice().sort((a, b) => b.name - a.name).map(d => d.name).filter(Boolean).join('</li><li>')}
        </li></ul>
      \`)
      .ringsData(dbmi)
      .ringMaxRadius('maxR')
      .ringPropagationSpeed('propagationSpeed')
      .ringRepeatPeriod('repeatPeriod')
      .ringColor(() => colorInterpolator)
      .enablePointerInteraction(true);

    fetch('./locations.csv').then(res => res.text())
      .then(csv => d3.csvParse(csv, ({ name, lat, lng }) => ({ name: name, lat: +lat, lng: +lng })))
      .then(data => world.hexBinPointsData(data));

    // Add auto-rotation
    world.controls().autoRotate = true;
    world.controls().autoRotateSpeed = 0.1;
  </script>
</body>
" > $(pwd)/docs/index.html

    git add ./* 2> /dev/null
    git commit -m "update website"
    git push
}

main() {
    form_link_file=""
    for i in "$@"; do
    case $i in
        -f|--formlinkfile)
        form_link_file="$2"
        shift
        shift
        ;;
        *)    
        ;;
    esac
    done
    [ -z "$form_link_file" ] && die "form link file not passed!"
    dl_googlesheet
    build_website
}

die() {
    printf 'error: %s.\n' "$1" >&2
    exit 1
}

main "$@"
