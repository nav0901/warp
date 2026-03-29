/**
 * PipelineContext - The shared data bag that flows through the entire pipeline.
 * 
 * Each step reads inputs from upstream steps and writes outputs for
 * downstream steps via this context. The framework automatically stores
 * each step's StepResult.data under the step's ID.
 * 
 * Also holds pipeline-level variables, step execution statuses,
 * trigger context (if invoked from a trigger), and governor limit snapshots.
 * 
 * Must be serializable (JSON) so it can be passed across Queueable boundaries
 * when the framework auto-escalates to async execution.
 */
public class PipelineContext {

    // Step outputs keyed by step ID
    private Map<String, Object> stepData;

    // Pipeline-level variables set at definition time
    private Map<String, Object> variables;

    // Step execution statuses
    private Map<String, StepStatus> stepStatuses;

    // Records from trigger context (if pipeline was triggered from a record trigger)
    private List<SObject> triggerRecords;

    // Pipeline metadata
    private String pipelineName;
    private Id pipelineRunId;
    private Long startTime;

    // Status enum for step tracking
    public enum StepStatus {
        PENDING,
        RUNNING,
        SUCCESS,
        FAILED,
        SKIPPED,
        RETRYING
    }

    // --- Constructor ---

    public PipelineContext() {
        this.stepData = new Map<String, Object>();
        this.variables = new Map<String, Object>();
        this.stepStatuses = new Map<String, StepStatus>();
        this.startTime = System.currentTimeMillis();
    }

    // --- Step Data: Read ---

    /**
     * Get output data from any step that has already executed.
     * Open access — any step can read from any completed step.
     * Returns null if step hasn't produced data.
     * Throws PipelineException if step exists but hasn't run yet.
     */
    public Object get(String stepId) {
        if (this.stepStatuses.containsKey(stepId) 
            && this.stepStatuses.get(stepId) == StepStatus.PENDING) {
            throw new PipelineException(
                stepId, 
                'Step "' + stepId + '" has not executed yet. '
                + 'You can only read from steps that have already run.'
            );
        }
        return this.stepData.get(stepId);
    }

    /**
     * Get output data cast to List<SObject>.
     * Common pattern since most Salesforce steps produce record lists.
     * Same access rules as get() — any completed step is readable.
     */
    public List<SObject> getRecords(String stepId) {
        Object data = this.get(stepId);  // uses the safety-checked get()
        if (data == null) return new List<SObject>();
        return (List<SObject>) data;
    }

    /**
     * Check if a step has produced output data.
     */
    public Boolean hasData(String stepId) {
        return this.stepData.containsKey(stepId);
    }

    // --- Step Data: Write ---

    /**
     * Store data under a key. Used by steps to write additional
     * outputs beyond their main StepResult.data.
     */
    public void put(String key, Object value) {
        this.stepData.put(key, value);
    }

    /**
     * Internal: called by the framework to store a step's result data
     * under the step's ID after execution.
     */
    public void setStepData(String stepId, Object data) {
        this.stepData.put(stepId, data);
    }

    // --- Pipeline Variables ---

    /**
     * Get a pipeline-level variable set at definition time.
     */
    public Object getVariable(String key) {
        return this.variables.get(key);
    }

    /**
     * Get a pipeline variable as String.
     */
    public String getVariableAsString(String key) {
        Object val = this.variables.get(key);
        return val != null ? String.valueOf(val) : null;
    }

    /**
     * Internal: called by Orchestrator builder to set pipeline variables.
     */
    public void setVariable(String key, Object value) {
        this.variables.put(key, value);
    }

    public Boolean hasVariable(String key) {
        return this.variables.containsKey(key);
    }

    // --- Step Status Tracking ---

    /**
     * Check if a specific step succeeded.
     */
    public Boolean stepSucceeded(String stepId) {
        return this.stepStatuses.get(stepId) == StepStatus.SUCCESS;
    }

    /**
     * Check if a specific step failed.
     */
    public Boolean stepFailed(String stepId) {
        return this.stepStatuses.get(stepId) == StepStatus.FAILED;
    }

    /**
     * Check if a specific step was skipped.
     */
    public Boolean stepSkipped(String stepId) {
        return this.stepStatuses.get(stepId) == StepStatus.SKIPPED;
    }

    /**
     * Get the raw status of a step.
     */
    public StepStatus getStepStatus(String stepId) {
        return this.stepStatuses.containsKey(stepId) 
            ? this.stepStatuses.get(stepId) 
            : StepStatus.PENDING;
    }

    /**
     * Internal: called by the framework to update step status.
     */
    public void setStepStatus(String stepId, StepStatus status) {
        this.stepStatuses.put(stepId, status);
    }

    /**
     * Get all step statuses (for logging/monitoring).
     */
    public Map<String, StepStatus> getAllStepStatuses() {
        return this.stepStatuses;
    }

    // --- Trigger Context ---

    /**
     * Get records from trigger context (if pipeline was invoked from a trigger).
     */
    public List<SObject> getTriggerRecords() {
        return this.triggerRecords != null ? this.triggerRecords : new List<SObject>();
    }

    /**
     * Internal: set trigger records when pipeline is invoked from a trigger.
     */
    public void setTriggerRecords(List<SObject> records) {
        this.triggerRecords = records;
    }

    // --- Pipeline Metadata ---

    public String getPipelineName() {
        return this.pipelineName;
    }

    public void setPipelineName(String name) {
        this.pipelineName = name;
    }

    public Id getPipelineRunId() {
        return this.pipelineRunId;
    }

    public void setPipelineRunId(Id runId) {
        this.pipelineRunId = runId;
    }

    /**
     * Elapsed time in milliseconds since pipeline started.
     */
    public Long getElapsedMs() {
        return System.currentTimeMillis() - this.startTime;
    }

    // --- Governor Limits ---

    /**
     * Get a snapshot of current governor limit usage.
     * Useful inside steps for making decisions based on remaining capacity.
     */
    public LimitSnapshot getLimits() {
        return new LimitSnapshot();
    }

    // --- Serialization ---

    /**
     * Serialize context to JSON for passing across Queueable boundaries.
     * Used by the framework during auto-async escalation.
     */
    public String serialize() {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('pipelineName', this.pipelineName);
        payload.put('pipelineRunId', this.pipelineRunId);
        payload.put('startTime', this.startTime);
        payload.put('variables', this.variables);
        // stepData and stepStatuses need careful handling for SObject serialization
        payload.put('stepStatuses', serializeStatuses());
        return JSON.serialize(payload);
    }

    private Map<String, String> serializeStatuses() {
        Map<String, String> result = new Map<String, String>();
        for (String key : this.stepStatuses.keySet()) {
            result.put(key, this.stepStatuses.get(key).name());
        }
        return result;
    }
}