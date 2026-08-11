package ai.quaynor

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class SamplerDslTest {

    @Test fun `shift steps are not silently dropped`() {
        // SamplerBuilder starts from the default config, so appended steps land at the tail.
        val json = buildSampler { topK(40); temperature(0.8); dist() }.toJson()
        val steps = JSONObject(json).getJSONArray("steps")
        assertTrue("expected at least 2 shift steps in resulting SamplerConfig, got: $json", steps.length() >= 2)
        val last = steps.getJSONObject(steps.length() - 1)
        val secondToLast = steps.getJSONObject(steps.length() - 2)
        assertEquals("top_k", secondToLast.getString("type"))
        assertEquals(40, secondToLast.getJSONObject("value").getInt("top_k"))
        assertEquals("temperature", last.getString("type"))
        assertEquals(0.8, last.getJSONObject("value").getDouble("temperature"), 1e-6)
    }

    @Test fun `default terminal is dist`() {
        assertNotNull(buildSampler { topK(40); temperature(0.8) })
    }

    @Test fun `explicit dist`() {
        assertNotNull(buildSampler { dist() })
    }

    @Test fun `explicit greedy`() {
        assertNotNull(buildSampler { greedy() })
    }

    @Test fun `explicit mirostatV1`() {
        assertNotNull(buildSampler { mirostatV1() })
    }

    @Test fun `explicit mirostatV2`() {
        assertNotNull(buildSampler { mirostatV2() })
    }

    @Test fun `all shift steps with dist`() {
        assertNotNull(buildSampler {
            topK(40); topP(0.9); minP(0.05); temperature(0.8)
            typicalP(0.95); xtc(0.1, 0.5); grammar("root ::= \"hi\"")
            dry(); penalties(); dist()
        })
    }

    @Test(expected = IllegalStateException::class)
    fun `double terminal throws`() {
        buildSampler { dist(); greedy() }
    }
}
