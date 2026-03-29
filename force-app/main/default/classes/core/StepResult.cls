/**
 * StepResult - The output of any IStep execution.
 * 
 * Every step returns a StepResult that tells the framework whether
 * it succeeded, what data it produced, and an optional message.
 * The framework stores result.data in PipelineContext under the step's ID
 * so downstream steps can access it.
 */
public class StepResult {

    public Boolean success;
    public Object data;
    public String message;

    // --- Constructors ---

    public StepResult(Boolean success, Object data, String message) {
        this.success = success;
        this.data = data;
        this.message = message;
    }

    public StepResult(Boolean success, Object data) {
        this(success, data, null);
    }

    // --- Static factory methods ---

    // Success with data
    public static StepResult success(Object data) {
        return new StepResult(true, data, null);
    }

    // Success with data and message
    public static StepResult success(Object data, String message) {
        return new StepResult(true, data, message);
    }

    // Success with message only (no data output)
    public static StepResult success(String message) {
        return new StepResult(true, null, message);
    }

    // Failure with error message
    public static StepResult error(String message) {
        return new StepResult(false, null, message);
    }

    // Failure with error message and partial data
    public static StepResult error(String message, Object data) {
        return new StepResult(false, data, message);
    }
}