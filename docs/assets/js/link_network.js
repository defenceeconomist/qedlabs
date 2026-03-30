const DEFAULT_WIDTH = 1100;
const DEFAULT_HEIGHT = 760;

const palette = {
  internal: {
    fill: "#2563eb",
    stroke: "#1e3a8a",
    edge: "rgba(37, 99, 235, 0.25)",
  },
  external: {
    fill: "#f59e0b",
    stroke: "#92400e",
    edge: "rgba(245, 158, 11, 0.25)",
  },
  muted: "#cbd5e1",
  text: "#0f172a",
};

const shell = document.getElementById("link-graph-shell");
const root = document.getElementById("link-graph-root");
const svgHost = document.getElementById("link-graph-svg");
const details = document.getElementById("link-graph-details");
const internalToggle = document.getElementById("toggle-internal");
const externalToggle = document.getElementById("toggle-external");
const fullscreenButton = document.getElementById("toggle-fullscreen");
const resetButton = document.getElementById("reset-link-graph");
const searchInput = document.getElementById("link-graph-search");
const nodeOptions = document.getElementById("link-graph-node-options");

if (
  shell &&
  root &&
  svgHost &&
  details &&
  internalToggle &&
  externalToggle &&
  fullscreenButton &&
  resetButton &&
  searchInput &&
  nodeOptions
) {
  initialise().catch((error) => {
    details.innerHTML = `
      <h3>Node Details</h3>
      <p>Unable to load the QED Labs network graph.</p>
      <p><code>${String(error.message || error)}</code></p>
    `;
  });
}

async function initialise() {
  const graph = window.__LINK_GRAPH__;
  if (!graph || !Array.isArray(graph.nodes) || !Array.isArray(graph.edges)) {
    throw new Error("Link graph payload is missing.");
  }

  let viewportWidth = DEFAULT_WIDTH;
  let viewportHeight = DEFAULT_HEIGHT;
  const shellPlaceholder = document.createComment("link-graph-shell-placeholder");

  const svg = d3
    .select(svgHost)
    .append("svg")
    .attr("viewBox", `0 0 ${viewportWidth} ${viewportHeight}`)
    .attr("class", "link-graph-svg-inner")
    .attr("role", "img")
    .attr("aria-label", "Interactive QED Labs link network");

  const nodes = graph.nodes.map((node) => ({ ...node }));
  const links = graph.edges.map((edge) => ({ ...edge }));

  const zoomLayer = svg.append("g").attr("class", "zoom-layer");
  const linkLayer = zoomLayer.append("g").attr("class", "link-layer");
  const nodeLayer = zoomLayer.append("g").attr("class", "node-layer");

  const simulation = d3
    .forceSimulation(nodes)
    .force(
      "link",
      d3
        .forceLink(links)
        .id((d) => d.id)
        .distance((d) => (d.kind === "external" ? 120 : 80))
        .strength((d) => (d.kind === "external" ? 0.18 : 0.32))
    )
    .force("charge", d3.forceManyBody().strength((d) => -120 - d.degree * 12))
    .force("center", d3.forceCenter(viewportWidth / 2, viewportHeight / 2))
    .force("collision", d3.forceCollide().radius((d) => nodeRadius(d) + 4));

  const link = linkLayer
    .selectAll("line")
    .data(links)
    .join("line")
    .attr("class", "graph-link")
    .attr("stroke", (d) => palette[d.kind].edge)
    .attr("stroke-width", (d) => (d.kind === "external" ? 1.4 : 1.8));

  const node = nodeLayer
    .selectAll("g")
    .data(nodes)
    .join("g")
    .attr("class", "graph-node")
    .style("cursor", "grab")
    .call(drag(simulation));

  node
    .append("circle")
    .attr("r", (d) => nodeRadius(d))
    .attr("fill", (d) => palette[d.kind].fill)
    .attr("stroke", (d) => palette[d.kind].stroke)
    .attr("stroke-width", 1.5);

  node
    .append("text")
    .attr("class", "graph-label")
    .attr("x", (d) => nodeRadius(d) + 6)
    .attr("y", 4)
    .text((d) => d.label);

  node.append("title").text((d) => nodeTitle(d));

  const zoom = d3
    .zoom()
    .scaleExtent([0.35, 3.5])
    .on("zoom", (event) => zoomLayer.attr("transform", event.transform));

  svg.call(zoom);

  populateNodeOptions(nodes);

  // Pre-settle the force layout so the first viewport fit uses the
  // network's true extent instead of the initial clustered positions.
  for (let i = 0; i < 220; i += 1) {
    simulation.tick();
  }
  renderPositions();

  simulation.on("tick", () => {
    renderPositions();
  });

  function renderPositions() {
    link
      .attr("x1", (d) => d.source.x)
      .attr("y1", (d) => d.source.y)
      .attr("x2", (d) => d.target.x)
      .attr("y2", (d) => d.target.y);

    node.attr("transform", (d) => `translate(${d.x},${d.y})`);
  }

  let selectedId = null;
  let currentSearch = "";

  node
    .on("mouseenter", (_, datum) => highlight(datum.id))
    .on("mouseleave", () => {
      if (selectedId) {
        highlight(selectedId);
      } else {
        clearHighlight();
      }
    })
    .on("click", (event, datum) => {
      event.stopPropagation();
      selectedId = datum.id;
      highlight(datum.id);
      renderDetails(datum, nodes, links);
    });

  svg.on("click", () => {
    selectedId = null;
    clearHighlight();
    details.innerHTML = `
      <h3>Node Details</h3>
      <p>Select a node to inspect its links.</p>
    `;
  });

  internalToggle.addEventListener("change", applyVisibility);
  externalToggle.addEventListener("change", applyVisibility);
  fullscreenButton.addEventListener("click", toggleModal);
  resetButton.addEventListener("click", () => resetView(true));
  searchInput.addEventListener("input", onSearchInput);
  details.addEventListener("click", onDetailsClick);
  document.addEventListener("keydown", onKeydown);

  const resizeObserver = new ResizeObserver(() => {
    updateViewport();
  });

  resizeObserver.observe(svgHost);

  applyVisibility();
  clearHighlight();
  updateViewport(true);
  syncExpandButton();

  function applyVisibility() {
    const visibleKinds = new Set();
    if (internalToggle.checked) visibleKinds.add("internal");
    if (externalToggle.checked) visibleKinds.add("external");

    node.attr("display", (d) => (visibleKinds.has(d.kind) ? null : "none"));
    link.attr("display", (d) => {
      const sourceVisible = visibleKinds.has(nodeKind(d.source));
      const targetVisible = visibleKinds.has(nodeKind(d.target));
      return sourceVisible && targetVisible ? null : "none";
    });

    if (selectedId) {
      const activeNode = nodes.find((item) => item.id === selectedId);
      if (activeNode && !visibleKinds.has(activeNode.kind)) {
        selectedId = null;
        clearHighlight();
      } else {
        highlight(selectedId);
      }
    }
  }

  function highlight(nodeId) {
    const adjacency = adjacentNodes(nodeId, links);

    node.attr("data-faded", (d) => (!adjacency.has(d.id) ? "true" : "false"));
    node.attr("data-selected", (d) => (d.id === nodeId ? "true" : "false"));
    link.attr("data-faded", (d) => {
      const sourceId = edgeEndpointId(d.source);
      const targetId = edgeEndpointId(d.target);
      return sourceId === nodeId || targetId === nodeId ? "false" : "true";
    });
    link.attr("data-selected", (d) => {
      const sourceId = edgeEndpointId(d.source);
      const targetId = edgeEndpointId(d.target);
      return sourceId === nodeId || targetId === nodeId ? "true" : "false";
    });
  }

  function clearHighlight() {
    node.attr("data-faded", "false");
    node.attr("data-selected", "false");
    link.attr("data-faded", "false");
    link.attr("data-selected", "false");
  }

  function updateSearchMatches(query) {
    const normalized = query.trim().toLowerCase();
    currentSearch = normalized;
    node.attr("data-search-match", (d) => {
      if (!normalized) return "false";
      const haystack = `${d.label} ${d.id}`.toLowerCase();
      return haystack.includes(normalized) ? "true" : "false";
    });
  }

  function focusNode(nodeId, zoomToNode = false) {
    const found = nodes.find((item) => item.id === nodeId);
    if (!found) return;
    selectedId = found.id;
    highlight(found.id);
    renderDetails(found, nodes, links);
    if (zoomToNode) {
      centerOnNode(found);
    }
  }

  function resetView(restart = false) {
    fitGraphToViewport(900);
    if (restart) {
      simulation.alpha(0.35).restart();
    }
  }

  function fitGraphToViewport(duration = 0) {
    const extent = nodeBounds(nodes);
    if (!extent) return;

    const width = Math.max(svgHost.clientWidth, 320);
    const height = Math.max(svgHost.clientHeight, 420);
    const boundsWidth = Math.max(extent.maxX - extent.minX, 1);
    const boundsHeight = Math.max(extent.maxY - extent.minY, 1);
    const padding = 70;
    const scale = Math.max(
      0.35,
      Math.min(2.2, 0.92 / Math.max(boundsWidth / (width - padding), boundsHeight / (height - padding)))
    );
    const centerX = (extent.minX + extent.maxX) / 2;
    const centerY = (extent.minY + extent.maxY) / 2;
    const tx = width / 2 - centerX * scale;
    const ty = height / 2 - centerY * scale;
    const transform = d3.zoomIdentity.translate(tx, ty).scale(scale);

    svg.transition().duration(duration).call(zoom.transform, transform);
  }

  function centerOnNode(targetNode) {
    const width = Math.max(svgHost.clientWidth, 320);
    const height = Math.max(svgHost.clientHeight, 420);
    const scale = Math.max(0.8, Math.min(1.8, 1.1 - targetNode.degree * 0.01));
    const tx = width / 2 - targetNode.x * scale;
    const ty = height / 2 - targetNode.y * scale;
    svg
      .transition()
      .duration(500)
      .call(zoom.transform, d3.zoomIdentity.translate(tx, ty).scale(scale));
  }

  function onSearchInput() {
    const raw = searchInput.value.trim();
    updateSearchMatches(raw);
    if (!raw) {
      if (selectedId) {
        highlight(selectedId);
      } else {
        clearHighlight();
      }
      return;
    }

    const normalized = raw.toLowerCase();
    const exact = nodes.find(
      (item) => item.label.toLowerCase() === normalized || item.id.toLowerCase() === normalized
    );
    const partial = exact || nodes.find((item) => `${item.label} ${item.id}`.toLowerCase().includes(normalized));
    if (partial) {
      focusNode(partial.id, true);
    }
  }

  function onDetailsClick(event) {
    if (event.target.closest("a[href]")) return;
    const button = event.target.closest("[data-node-id]");
    if (!button) return;
    const nodeId = button.getAttribute("data-node-id");
    if (!nodeId) return;
    focusNode(nodeId, true);
  }

  function toggleModal() {
    const opening = !shell.classList.contains("is-modal-open");
    if (opening) {
      if (!shellPlaceholder.parentNode && shell.parentNode) {
        shell.parentNode.insertBefore(shellPlaceholder, shell);
      }
      shell.classList.remove("page-columns", "page-full");
      root.classList.remove("page-columns", "page-full");
      document.body.appendChild(shell);
    } else if (shellPlaceholder.parentNode) {
      shell.classList.add("page-columns", "page-full");
      root.classList.add("page-columns", "page-full");
      shellPlaceholder.parentNode.insertBefore(shell, shellPlaceholder);
      shellPlaceholder.remove();
    }

    shell.classList.toggle("is-modal-open", opening);
    document.body.classList.toggle("link-graph-modal-open", opening);
    syncExpandButton();
    requestAnimationFrame(() => updateViewport(true));
  }

  function syncExpandButton() {
    const expanded = shell.classList.contains("is-modal-open");
    fullscreenButton.textContent = expanded ? "Close expanded view" : "Expand visual";
    fullscreenButton.setAttribute("aria-pressed", expanded ? "true" : "false");
  }

  function updateViewport(restart = false) {
    const nextWidth = Math.max(Math.round(svgHost.clientWidth), 320);
    const nextHeight = Math.max(Math.round(svgHost.clientHeight), 420);
    if (!restart && nextWidth === viewportWidth && nextHeight === viewportHeight) {
      return;
    }

    viewportWidth = nextWidth;
    viewportHeight = nextHeight;
    svg.attr("viewBox", `0 0 ${viewportWidth} ${viewportHeight}`);
    simulation.force("center", d3.forceCenter(viewportWidth / 2, viewportHeight / 2));
    simulation.alpha(restart ? 0.45 : 0.2).restart();
    requestAnimationFrame(() => fitGraphToViewport(restart ? 250 : 0));
  }

  function onKeydown(event) {
    if (event.key === "Escape" && shell.classList.contains("is-modal-open")) {
      toggleModal();
    }
  }

  function populateNodeOptions(items) {
    const markup = items
      .slice()
      .sort((a, b) => a.label.localeCompare(b.label))
      .map((item) => `<option value="${escapeHtml(item.label)}"></option>`)
      .join("");
    nodeOptions.innerHTML = markup;
  }
}

function nodeRadius(node) {
  return 6 + Math.min(node.degree * 0.9, 18);
}

function nodeKind(nodeOrId) {
  return typeof nodeOrId === "object" ? nodeOrId.kind : null;
}

function edgeEndpointId(endpoint) {
  return typeof endpoint === "object" ? endpoint.id : endpoint;
}

function adjacentNodes(nodeId, links) {
  const ids = new Set([nodeId]);
  links.forEach((link) => {
    const sourceId = edgeEndpointId(link.source);
    const targetId = edgeEndpointId(link.target);
    if (sourceId === nodeId) ids.add(targetId);
    if (targetId === nodeId) ids.add(sourceId);
  });
  return ids;
}

function internalRenderPath(node) {
  if (!node.path) return null;
  const offset =
    document.querySelector('meta[name="quarto:offset"]')?.getAttribute("content") || "./";
  const withOffset = (path) => {
    try {
      const resolved = new URL(`${offset}${path}`, window.location.href);
      return `${resolved.pathname}${resolved.search}${resolved.hash}`;
    } catch (_) {
      return `${offset}${path}`;
    }
  };
  if (node.path === "knowledge-base/index.qmd") return withOffset("knowledge-base/index.html");
  if (node.path === "reports/index.qmd") return withOffset("reports/index.html");
  if (node.path.endsWith(".qmd")) {
    if (node.path.endsWith("/index.qmd")) {
      return withOffset(node.path.replace(/index\.qmd$/, "index.html"));
    }
    if (node.path === "index.qmd") {
      return withOffset("index.html");
    }
    return withOffset(node.path.replace(/\.qmd$/, ".html"));
  }
  if (node.path.endsWith(".html")) {
    return node.path.startsWith("/") ? node.path : withOffset(node.path);
  }
  return null;
}

function clickableUrl(node) {
  if (node.kind === "external") return node.url || null;
  return internalRenderPath(node);
}

function nodeTitle(node) {
  const target = clickableUrl(node);
  const path = node.path || node.url || "";
  return `${node.label}\n${path}${target ? `\nTarget: ${target}` : ""}`;
}

function renderDetails(node, nodes, links) {
  const related = links
    .filter((link) => {
      const sourceId = edgeEndpointId(link.source);
      const targetId = edgeEndpointId(link.target);
      return sourceId === node.id || targetId === node.id;
    })
    .map((link) => {
      const sourceId = edgeEndpointId(link.source);
      const targetId = edgeEndpointId(link.target);
      const otherId = sourceId === node.id ? targetId : sourceId;
      return nodes.find((item) => item.id === otherId);
    })
    .filter(Boolean)
    .sort((a, b) => {
      if (b.degree !== a.degree) return b.degree - a.degree;
      return a.label.localeCompare(b.label);
    });

  const target = clickableUrl(node);
  const meta = node.kind === "internal" ? (node.path || "") : (node.url || "");

  const relatedMarkup = related.length
    ? `<ul>${related
        .slice(0, 16)
        .map(
          (item) =>
            `<li><button class="link-graph-related-button" type="button" data-node-id="${escapeHtml(item.id)}"><span class="kind-pill ${item.kind}">${item.kind}</span> ${escapeHtml(item.label)}</button></li>`
        )
        .join("")}</ul>`
    : "<p>No related links recorded.</p>";

  details.innerHTML = `
    <h3>${escapeHtml(node.label)}</h3>
    <p><span class="kind-pill ${node.kind}">${node.kind}</span></p>
    <p class="detail-meta"><strong>ID:</strong> <code>${escapeHtml(meta)}</code></p>
    <p class="detail-meta"><strong>Degree:</strong> ${node.degree} (${node.incoming} incoming, ${node.outgoing} outgoing)</p>
    ${
      target
        ? `<p class="detail-actions"><a href="${escapeHtml(target)}"${
            node.kind === "external" ? ' target="_blank" rel="noopener noreferrer"' : ""
          }>Open target</a></p>`
        : ""
    }
    <h4>Connected nodes</h4>
    ${relatedMarkup}
  `;
}

function nodeBounds(nodes) {
  const positioned = nodes.filter((node) => Number.isFinite(node.x) && Number.isFinite(node.y));
  if (!positioned.length) return null;
  return positioned.reduce(
    (acc, node) => ({
      minX: Math.min(acc.minX, node.x),
      maxX: Math.max(acc.maxX, node.x),
      minY: Math.min(acc.minY, node.y),
      maxY: Math.max(acc.maxY, node.y),
    }),
    { minX: Infinity, maxX: -Infinity, minY: Infinity, maxY: -Infinity }
  );
}

function drag(simulation) {
  function dragstarted(event) {
    if (!event.active) simulation.alphaTarget(0.3).restart();
    event.subject.fx = event.subject.x;
    event.subject.fy = event.subject.y;
  }

  function dragged(event) {
    event.subject.fx = event.x;
    event.subject.fy = event.y;
  }

  function dragended(event) {
    if (!event.active) simulation.alphaTarget(0);
    event.subject.fx = null;
    event.subject.fy = null;
  }

  return d3.drag().on("start", dragstarted).on("drag", dragged).on("end", dragended);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
