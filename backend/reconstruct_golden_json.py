import json

def reconstruct_json():
    analysis_text = """**1. The Core Claim(s):**
The claim suggests that drinking lemon water every morning significantly boosts metabolism and cures chronic digestive diseases.

**2. Evidence Breakdown:**
*   Lemon water may support hydration, boost metabolism, and increase weight loss.
*   Drinking water, including lemon water, can temporarily increase metabolic rate. A study indicated that consuming about 500ml of water could boost metabolic rate by approximately 30% for about 30-40 minutes.
*   Lemon water is not a miracle cure for gut health issues.
*   The citric acid in lemons may help stimulate gastric acid production, which is crucial for breaking down food.
*   Lemon water may offer some digestive benefits but should not be viewed as a cure-all for gut health.
*   Lemon juice can help stimulate digestive enzymes and reduce bloating, offering relief from mild indigestion.
*   Lemon can worsen symptoms in people with acid reflux or GERD due to its acidity.
*   Lemon water is not necessarily better than regular water for fat loss.

**3. Context & Nuance:**
While lemon water can provide some benefits such as boosting metabolism and aiding digestion, it is not a cure for chronic digestive diseases. The metabolic boost primarily comes from the water content, not the lemon itself. Lemon can help with minor digestive issues, but persistent indigestion may indicate an underlying problem requiring medical advice.

**4. Red Flags & Discrepancies:**
No major discrepancies found in the verified sources."""

    segments_data = [
        ("Lemon water may support hydration, boost metabolism, and increase weight loss.", [1, 2], [0.85, 0.75]),
        ("Drinking water, including lemon water, can temporarily increase metabolic rate.", [1], [0.95]),
        ("A study indicated that consuming about 500ml of water could boost metabolic rate by approximately 30% for about 30-40 minutes.", [1], [0.96]),
        ("Lemon water is not a miracle cure for gut health issues.", [3, 4], [0.90, 0.88]),
        ("The citric acid in lemons may help stimulate gastric acid production, which is crucial for breaking down food.", [3], [0.92]),
        ("Lemon water may offer some digestive benefits but should not be viewed as a cure-all for gut health.", [4], [0.85]),
        ("Lemon juice can help stimulate digestive enzymes and reduce bloating, offering relief from mild indigestion.", [5], [0.88]),
        ("Lemon can worsen symptoms in people with acid reflux or GERD due to its acidity.", [6], [0.94]),
        ("Lemon water is not necessarily better than regular water for fat loss.", [2], [0.70])
    ]

    target_snippets = {
        1: "A study found that drinking 500ml of water increased metabolic rate by 30% for 30–40 minutes. While lemon adds Vitamin C, the metabolic boost is primarily driven by water thermogenesis.",
        2: "There is no scientific evidence that lemon water 'cures' chronic digestive diseases. However, the atomic structure of lemon juice is similar to digestive juices, which may help stimulate bile production.",
        3: "The citric acid in lemons can excite the production of gastric acid, a digestive fluid that helps your body break down and digest food. It may also help stimulate the liver to produce bile.",
        4: "While some animal studies suggest that lemon polyphenols can help prevent weight gain, human evidence is lacking. The main weight-loss benefit is likely displacement of higher-calorie drinks.",
        5: "Lemon juice contains enzymes that mimic natural digestive juices. Regular consumption can help promote a healthy digestive environment by assisting in the breakdown of complex proteins.",
        6: "Medical experts warn that excessive lemon water consumption can lead to dental erosion and may exacerbate symptoms of gastroesophageal reflux disease (GERD) in sensitive individuals."
    }

    citations = [
        {
            "id": 1,
            "title": "cymbiotika.com",
            "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQHhImZuUntzAwmckf3_-v5fHoYHMofUDqkAmCzniWy0lgNXX62uva16_-7hUPeBFvqDsJKFmGLsiN5oUn--8GQOG2jPSK9KNVUiAyL5RVzcbU01--_969LYpi3zMGVMxREO0VJtyToGx3Rf1XB0CiY7tronamn5a5JferQq5HWO1Rfr9EzbNVklV5Vf9TdTII_Hkphisay3Wl0lDXMAUWEXdYGdK53is4P0BG5ww1Y4F1TAXg2xKA==",
            "snippet": target_snippets[1]
        },
        {
            "id": 2,
            "title": "healthline.com",
            "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQHJ06Mybx_ntlSGkhYj0AHqM-q-beBYrNJLJaFHFndhsOrPP5wwJNmLTpD2QT0qZT5vXbuwbkEOpE-WlTZdXV6ROzV0KDHYFNFKbq2YCwNkx493dphQk6Hy2tYOegeQ3_R8u4s5FrZzPue4xkucdfQjyu1RVhmZmiGWg68=",
            "snippet": target_snippets[2]
        },
        {
            "id": 3,
            "title": "clevelandclinic.org",
            "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQEgB1f0ALP3dAdrzHM4_IQpgcpCFmnthEIHg3plf6B0PyWapHCt4CUNql6eAaDjVcJifCFiAeKefUeJVBcyyW6AJjNb5hYdBc1URP_t5qdPLMP-SA45VrAh-vnc8sqkiPPrU1DK9-AotfYkAIp1hLBxA4TLXXw=",
            "snippet": target_snippets[3]
        },
        {
            "id": 4,
            "title": "healthline.com",
            "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQGBgIH6tnDkv5IasoTDajQTDzROUuXLVQgx-l8UJcmKQv7fhLJxWua_9-0vk5WL9uEnFZR3MzkyRvpgfp8CW1Lh3Gf6mQs3LM29xKXeLo6S9cKO5G_L_p3z5j1RMDRldm7e9QxSoKPjGH801onhh-iT2c9k3vIDrEzVFxRHIpm69Y3SBg==",
            "snippet": target_snippets[4]
        },
        {
            "id": 5,
            "title": "sahyadrihospital.com",
            "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQE7xTYHEH7_vTkmO-TLFFcu5hwM0jJmwCrPwH9PYtV7IinT3uwMQKVPnWnZMiREcNAxWJHhVEU9GwDN4xN-p3tINtcXbda7yU9e9f48kj2I6DOAQGnvazGeSUFZ_-5MhWsOy_IebrFbQwCO5bx0KL0vmyyqTLPs210xWJI=",
            "snippet": target_snippets[5]
        },
        {
            "id": 6,
            "title": "indiatimes.com",
            "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQGRs4KpyiUDBUI3ES7M9ZvGXS4uqOmz5N5p8cvrpEAygMuPuk4kr7PgjDuF1EIkIWzDr9E5ZjXq97hb5Zo0tkyJlUI3rWrjnGGUhlq2Nzv299qwgXhW4455O3glEYAX5UQMrtUk9LJkxm54dxTG5wUV3QnjVG54SSkqdRr4Zy4xlN1nzf30HqsWqdKi1GRMCZMw5DB5_g5fMdYLgc18kU1fnsip_-wwR9R2pt-KObhVes7FYqHV_9YhtmOc1qw0f5kaXZJNVkWrOsPlAb-e",
            "snippet": target_snippets[6]
        }
    ]

    scanned_sources = []
    for c in citations:
        scanned_sources.append({
            "id": c["id"],
            "title": c["title"],
            "url": c["url"],
            "is_cited": True,
            "snippet": c["snippet"]
        })

    grounding_supports = []
    reliability_segments = []

    for text, source_ids, conf_scores in segments_data:
        start = analysis_text.find(text)
        if start == -1:
            print(f"Warning: Segment not found: {text}")
            continue
        end = start + len(text)

        grounding_supports.append({
            "confidence_scores": conf_scores,
            "grounding_chunk_indices": [sid - 1 for sid in source_ids],
            "segment": {
                "start_index": start,
                "end_index": end,
                "text": text,
                "part_index": 0
            }
        })

        segment_sources = []
        for i, sid in enumerate(source_ids):
            citation = next(c for c in citations if c["id"] == sid)
            segment_sources.append({
                "id": sid,
                "chunk_index": sid - 1,
                "source_index": 0,
                "domain": citation["title"],
                "score": conf_scores[i],
                "quote_text": citation["title"],
                "confidence": conf_scores[i],
                "authority": 0.8,
                "is_verified": False,
                "snippet": citation["snippet"]
            })

        reliability_segments.append({
            "text": text,
            "top_source_domain": segment_sources[0]["domain"],
            "top_source_score": segment_sources[0]["score"],
            "sources": segment_sources
        })

    final_json = {
        "verdict": "MIXTURE",
        "confidence_score": 0.85,
        "analysis": analysis_text,
        "multimodal_cross_check": False,
        "reliability_metrics": {
            "reliability_score": 0.6493765217,
            "ai_confidence": 0.85,
            "base_grounding": 0.5993765217,
            "consistency_bonus": 0.05,
            "multimodal_bonus": 0.0,
            "verdict_label": "Medium (Mixed/Uncertain)",
            "explanation": "Base grounding evaluated at 0.60 across 9 segments. Consistency bonus (+0.05) applied for 6 unique domains.",
            "segments": reliability_segments,
            "unused_sources": []
        },
        "grounding_citations": citations,
        "scanned_sources": scanned_sources,
        "grounding_supports": grounding_supports
    }

    with open("c:/Users/User/Documents/Gemini3Pro/frontend/assets/data/demo_lemon_analysis.json", "w", encoding="utf-8") as f:
        json.dump(final_json, f, indent=4)
    print("Forensic Data Reconstituted Successfully.")

if __name__ == "__main__":
    reconstruct_json()
