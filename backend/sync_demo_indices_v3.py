import json

json_path = r'c:\Users\User\Documents\Gemini3Pro\frontend\assets\data\demo_lemon_analysis.json'

with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

analysis_text = data['analysis']

# Segment mapping (Text snippet from analysis -> List of Source IDs)
targets = [
    {
        "text": "Lemon water may support hydration, boost metabolism, and increase weight loss.",
        "sources": [1, 2],
        "confidence": [0.85, 0.75]
    },
    {
        "text": "Drinking water, including lemon water, can temporarily increase metabolic rate.",
        "sources": [1],
        "confidence": [0.95]
    },
    {
        "text": "A study indicated that consuming about 500ml of water could boost metabolic rate by approximately 30% for about 30-40 minutes.",
        "sources": [1],
        "confidence": [0.96]
    },
    {
        "text": "Lemon water is not a miracle cure for gut health issues.",
        "sources": [3, 4],
        "confidence": [0.90, 0.88]
    },
    {
        "text": "The citric acid in lemons may help stimulate gastric acid production, which is crucial for breaking down food.",
        "sources": [3],
        "confidence": [0.92]
    },
    {
        "text": "Lemon water may offer some digestive benefits but should not be viewed as a cure-all for gut health.",
        "sources": [4],
        "confidence": [0.85]
    },
    {
        "text": "Lemon juice can help stimulate digestive enzymes and reduce bloating, offering relief from mild indigestion.",
        "sources": [5],
        "confidence": [0.88]
    },
    {
        "text": "Lemon can worsen symptoms in people with acid reflux or GERD due to its acidity.",
        "sources": [6],
        "confidence": [0.94]
    },
    {
        "text": "Lemon water is not necessarily better than regular water for fat loss.",
        "sources": [2],
        "confidence": [0.70]
    }
]

new_supports = []
cited_ids = set()

for target in targets:
    index = analysis_text.find(target['text'])
    if index != -1:
        new_supports.append({
            "confidence_scores": target['confidence'],
            "grounding_chunk_indices": [s-1 for s in target['sources']],
            "segment": {
                "end_index": index + len(target['text']),
                "part_index": 0,
                "start_index": index,
                "text": target['text']
            }
        })
        for s in target['sources']:
            cited_ids.add(s)
        print(f"Found: {target['text'][:30]}... at {index}")
    else:
        print(f"NOT FOUND: {target['text'][:30]}...")

data['grounding_supports'] = new_supports

# Update scanned_sources is_cited flag
for source in data['scanned_sources']:
    if source['id'] in cited_ids:
        source['is_cited'] = True
    else:
        source['is_cited'] = False

# Also update grounding_citations list to match the cited sources
new_citations = []
for source_id in sorted(list(cited_ids)):
    scanned = next((s for s in data['scanned_sources'] if s['id'] == source_id), None)
    if scanned:
        new_citations.append({
            "id": source_id,
            "title": scanned['title'],
            "url": scanned['url'],
            "snippet": f"Verified information from {scanned['title']}."
        })
data['grounding_citations'] = new_citations

# Sync reliability_metrics.segments
new_metric_segments = []
for support in new_supports:
    segment_text = support['segment']['text']
    sources_audit = []
    for i, chunk_idx in enumerate(support['grounding_chunk_indices']):
        source_id = chunk_idx + 1
        scanned = next((s for s in data['scanned_sources'] if s['id'] == source_id), None)
        domain = scanned['title'] if scanned else "unknown.com"
        
        sources_audit.append({
            "id": source_id,
            "chunk_index": chunk_idx,
            "source_index": 0,
            "domain": domain,
            "score": support['confidence_scores'][i],
            "quote_text": domain,
            "confidence": support['confidence_scores'][i],
            "authority": 0.8,
            "is_verified": False
        })
    
    new_metric_segments.append({
        "text": segment_text,
        "top_source_domain": sources_audit[0]['domain'] if sources_audit else "unknown",
        "top_source_score": sources_audit[0]['score'] if sources_audit else 0.0,
        "sources": sources_audit
    })

data['reliability_metrics']['segments'] = new_metric_segments

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=4)

print(f"Sync complete. Created {len(new_supports)} segments. {len(cited_ids)} sources cited.")
