## Introduction

The following document will record the midterm interview for this project. During the interview, we first ran our build script from which questions were asked. This document attempts to capture all the questions and answers asked during the interview. Note that this will not be a 100% perfect replication of the interview.

## Questions and Answers

### Question 1: Build Script

Questions were asked about each section of the build script, including:
- The purpose and functionality of each section of the code.
- Idempotency and how it is implemented.
- The structure and consistency of code comments.

**Key Observations / Feedback:**

1. **Idempotency:** Idempotency has been hard-coded, which is not ideal. This should be reconsidered and improved.
2. **Comment Structure:** The comment structure should be consistent throughout the codebase.

### Question 2: Does the Order of Operations Within the Build Script Matter?

**Answer:**

Yes. The order in which things are built within the build script is important. If tables, constraints, and other essential components are not built in the correct order, data loading and other important operations can be compromised, resulting in inaccurate data. Therefore, the order of operations does matter.

### Question 3: Do You Have Logs? Do You Have a Way to Audit the Data?

**Answer:**

No. This is a significant blind spot in the current database implementation.

**Key Observations / Feedback:**

- Auditing and logging are among the most important things to consider moving forward.
- A proper auditing mechanism needs to be incorporated into the database.

### Question 4: How Are You Dealing With Contention?

**Answer:**

The controlled procedures use transactions, row locks, and rollback handlers. Booking and rescheduling lock relevant rows before checking availability and overlap. Database roles also limit normal users to the controlled procedures instead of direct appointment changes. Additional concurrent-user testing is still needed.

### Question 5: Do You Have a Way to Deal With Overlap in Your Procedures?

**Answer:**

Overlap was planned for but was not fully addressed or implemented due to a lack of time.

**Key Observations / Feedback:**

- Procedure overlap needs to be revisited and properly addressed.

### Question 6: Can You Prove That Your Database Works at Scale?

**Discussion / Key Observations:**

The professor asked several probing questions regarding the ability to demonstrate that the database works at scale.

**Important Takeaway:**

- We need approximately 10,000 data points to validate and demonstrate how well our database scales.

### Question 7: How Do You Ensure That When Somebody New Joins the Application, They Maintain the Existing Business Rules and Processes?

**Answer / Key Insight:**

Documentation alone is not sufficient to ensure that new users maintain existing business rules and processes.

**Professor's Recommendation:**

Refer to the announcement on Canvas:

> "Put the workflow in the database, as data".

**Important Takeaway:**

- Business workflows and rules should be represented and maintained within the database itself, rather than relying exclusively on external documentation.
- This is an important architectural consideration to carry forward into the final project.


## Next Steps

1. The current data model is more customer facing and not very useful for the manager. Figure out a new data model and update the documents (TDD, ERD, FRD) accordingly.

2. Come up with a plan regarding the following:
   - Auditing
   - Workflow and RBAC
   - Metadata
